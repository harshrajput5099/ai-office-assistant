# backend/routers/meeting.py

from fastapi import APIRouter, UploadFile, File, HTTPException
from faster_whisper import WhisperModel
import httpx
import tempfile
import os

router = APIRouter()

PROMPT_DIR = os.path.join(os.path.dirname(__file__), '..', 'prompts')

# ── Load Whisper (keeping your existing setup) ─────────────────────
whisper_model = WhisperModel('small', device='cuda', compute_type='float16')

# ── Helper: load meeting notes prompt ─────────────────────────────
def load_meeting_prompt(transcript: str) -> str:
    try:
        with open(os.path.join(PROMPT_DIR, 'meeting_notes.txt'), 'r') as f:
            template = f.read()
        return template.format(transcript=transcript)
    except FileNotFoundError:
        return f'Convert this meeting transcript into structured notes:\n{transcript}'

# ── Helper: summarize via Ollama Mistral ──────────────────────────
async def summarize_transcript(transcript: str) -> str:
    prompt = load_meeting_prompt(transcript)
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                'http://localhost:11434/api/generate',
                json={'model': 'mistral', 'prompt': prompt, 'stream': False},
                timeout=120.0
            )
        response.raise_for_status()
        return response.json().get('response', '').strip()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504,
            detail='Mistral timed out. Make sure Ollama is running.')
    except httpx.ConnectError:
        raise HTTPException(status_code=503,
            detail='Cannot connect to Ollama. Run: ollama serve')

# ── Main endpoint ──────────────────────────────────────────────────
@router.post('/transcribe-meeting')
async def transcribe_meeting(audio: UploadFile = File(...)):
    allowed = ['.mp3', '.wav', '.m4a', '.ogg']
    ext = os.path.splitext(audio.filename)[1].lower()
    if ext not in allowed:
        raise HTTPException(status_code=400,
            detail=f'Unsupported format. Use: {allowed}')

    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(await audio.read())
        tmp_path = tmp.name

    try:
        # Step 1 — Transcribe with faster_whisper
        segments, info = whisper_model.transcribe(tmp_path, beam_size=5)
        transcript = ' '.join([seg.text for seg in segments]).strip()

        if not transcript:
            raise HTTPException(status_code=400,
                detail='No speech detected in the audio file.')

        # Step 2 — Summarize with Ollama Mistral (no T5 limit)
        notes = await summarize_transcript(transcript)

        return {
            'transcript': transcript,
            'notes': notes,
            'language': info.language
        }
    finally:
        os.unlink(tmp_path)