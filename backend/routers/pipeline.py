# Single endpoint: POST /api/pipeline/run
# Runs: audio → transcript → summary+extract → email draft
# All 3 stages happen on the backend in one request.

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import Optional
import httpx
import os
import tempfile
import whisper

router = APIRouter()

# ── Load Whisper once at startup ──────────────────────────────
try:
    _whisper = whisper.load_model('base')
    print('✅ Pipeline: Whisper loaded')
except Exception as e:
    _whisper = None
    print(f'⚠️  Pipeline: Whisper not loaded: {e}')

PROMPT_DIR = os.path.join(os.path.dirname(__file__), '..', 'prompts')
OLLAMA_URL = 'http://localhost:11434/api/generate'

# ── Helper: call Mistral via Ollama ───────────────────────────
async def _mistral(prompt: str, max_wait: int = 120) -> str:
    async with httpx.AsyncClient() as client:
        res = await client.post(
            OLLAMA_URL,
            json={'model': 'mistral', 'prompt': prompt, 'stream': False},
            timeout=max_wait
        )
    res.raise_for_status()
    return res.json().get('response', '').strip()

# ── Helper: load a prompt file ────────────────────────────────
def _load_prompt(filename: str) -> str:
    path = os.path.join(PROMPT_DIR, filename)
    try:
        with open(path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return ''

# ══════════════════════════════════════════════════════════════
# MAIN PIPELINE ENDPOINT
# ══════════════════════════════════════════════════════════════
# Accepts EITHER an audio file OR raw transcript text.
# If both provided, audio takes priority.
# Returns all 3 stage outputs so the Flutter UI can display each.
@router.post('/pipeline/run')
async def run_pipeline(
    audio: Optional[UploadFile] = File(None),
    transcript_text: Optional[str] = Form(None),
    tone: str = Form('formal'),
    recipient_role: str = Form(''),
):
    # ────────────────────────────────────────────────────────
    # STAGE 1 — Get transcript
    # ────────────────────────────────────────────────────────
    transcript = ''
    stage1_source = 'typed'

    if audio and audio.filename:
        # Audio file provided — run Whisper
        if _whisper is None:
            raise HTTPException(503, 'Whisper not loaded. Run: pip install openai-whisper')
        allowed = ['.mp3', '.wav', '.m4a', '.ogg', '.flac']
        ext = os.path.splitext(audio.filename)[1].lower()
        if ext not in allowed:
            raise HTTPException(400, f'Unsupported audio type: {ext}')
        content = await audio.read()
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        try:
            result = _whisper.transcribe(tmp_path)
            transcript = result['text'].strip()
            stage1_source = 'whisper'
        finally:
            os.unlink(tmp_path)
    elif transcript_text:
        # Raw text provided — skip Whisper
        transcript = transcript_text.strip()
    else:
        raise HTTPException(400, 'Provide either an audio file or transcript text.')

    if not transcript:
        raise HTTPException(400, 'No transcript content found.')

    # ────────────────────────────────────────────────────────
    # STAGE 2 — Summarize + Extract email metadata
    # ────────────────────────────────────────────────────────
    extract_template = _load_prompt('pipeline_extract.txt')
    if not extract_template:
        # Fallback if prompt file missing
        extract_template = '''
You are a meeting analyst. Analyze this meeting transcript and extract:

1. SUMMARY: 2-3 sentences describing what the meeting was about.
2. KEY_POINTS: 3-5 bullet points of the most important discussion points.
3. ACTION_ITEMS: Tasks assigned, with person responsible if mentioned.
4. EMAIL_PURPOSE: One sentence describing the purpose of a follow-up email.
5. RECIPIENT_ROLE: Who the follow-up email should be sent to (e.g. Manager, Client, Team).
6. DECISIONS: Any decisions made in the meeting.

Respond ONLY in this exact format with no extra text:
SUMMARY: [text]
KEY_POINTS:
- [point 1]
- [point 2]
ACTION_ITEMS:
- [item 1]
DECISIONS: [text or None]
EMAIL_PURPOSE: [text]
RECIPIENT_ROLE: [text]

Transcript:
{transcript}
'''

    extract_prompt = extract_template.format(transcript=transcript)
    try:
        extracted_raw = await _mistral(extract_prompt, max_wait=150)
    except Exception as e:
        raise HTTPException(503, f'Mistral not responding: {e}. Is Ollama running?')

    # Parse the structured output
    parsed = _parse_extraction(extracted_raw)

    # Use form recipient_role if provided, otherwise use detected one
    final_recipient = recipient_role.strip() or parsed.get('recipient_role', 'Team')

    # ────────────────────────────────────────────────────────
    # STAGE 3 — Generate email draft
    # ────────────────────────────────────────────────────────
    email_template = _load_prompt(f'email_{tone}.txt')
    if not email_template:
        email_template = _load_prompt('email_formal.txt')
    if not email_template:
        # Final fallback
        email_template = '''
Write a {tone} professional email.
Purpose: {purpose}
Recipient: {recipient_role}
Key Points: {key_points}
Action Items: {action_items}
Required: Confirm receipt and next steps.
Output ONLY the email — no preamble.
'''

    key_points_str   = parsed.get('key_points', 'See meeting notes')
    action_items_str = parsed.get('action_items', 'See meeting notes')
    purpose_str      = parsed.get('email_purpose', f'Follow-up from meeting')

    email_prompt = email_template.format(
        purpose       = purpose_str,
        recipient_role= final_recipient,
        key_points    = key_points_str,
        required_response = 'Please confirm receipt and any next steps.',
    )

    # Also append action items to email prompt for better context
    email_prompt += f'\n\nAction items from the meeting: {action_items_str}'

    try:
        email_draft = await _mistral(email_prompt, max_wait=180)
    except Exception as e:
        raise HTTPException(503, f'Email generation failed: {e}')

    # ────────────────────────────────────────────────────────
    # Return all 3 outputs
    # ────────────────────────────────────────────────────────
    return {
        'stage1_transcript':  transcript,
        'stage1_source':      stage1_source,
        'stage2_summary':     parsed.get('summary', ''),
        'stage2_key_points':  parsed.get('key_points', ''),
        'stage2_action_items':parsed.get('action_items', ''),
        'stage2_decisions':   parsed.get('decisions', ''),
        'stage2_full_raw':    extracted_raw,
        'stage3_email':       email_draft,
        'tone_used':          tone,
        'recipient_used':     final_recipient,
    }


# ── Parser for Stage 2 output ──────────────────────────────────
def _parse_extraction(raw: str) -> dict:
    """
    Parses Mistral's structured output into a dict.
    Robust to slight formatting variations.
    """
    result = {
        'summary': '',
        'key_points': '',
        'action_items': '',
        'decisions': '',
        'email_purpose': '',
        'recipient_role': '',
    }
    lines = raw.split('\n')
    current_key = None
    buffer = []

    key_map = {
        'SUMMARY':        'summary',
        'KEY_POINTS':     'key_points',
        'ACTION_ITEMS':   'action_items',
        'DECISIONS':      'decisions',
        'EMAIL_PURPOSE':  'email_purpose',
        'RECIPIENT_ROLE': 'recipient_role',
    }

    for line in lines:
        matched = False
        for marker, key in key_map.items():
            if line.upper().startswith(marker + ':'):
                if current_key and buffer:
                    result[current_key] = '\n'.join(buffer).strip()
                current_key = key
                rest = line[len(marker)+1:].strip()
                buffer = [rest] if rest else []
                matched = True
                break
        if not matched and current_key:
            buffer.append(line)

    if current_key and buffer:
        result[current_key] = '\n'.join(buffer).strip()

    return result
