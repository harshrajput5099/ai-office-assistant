# backend/routers/meeting.py
from fastapi import APIRouter, UploadFile, File, HTTPException
from faster_whisper import WhisperModel
from models.t5_model import summarize_chunk
import tempfile, os

router = APIRouter()

# Load Whisper model once (use 'small' for speed, 'medium' for accuracy)
whisper_model = WhisperModel('small', device='cuda', compute_type='float16')

@router.post('/transcribe-meeting')
async def transcribe_meeting(file: UploadFile = File(...)):
    allowed = ['.mp3', '.wav', '.m4a', '.ogg']
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed:
        raise HTTPException(400, f'Unsupported format. Use: {allowed}')

    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        # Transcribe with Whisper
        segments, _ = whisper_model.transcribe(tmp_path, beam_size=5)
        transcript = ' '.join([seg.text for seg in segments])

        # Summarize the transcript
        summary = summarize_chunk(transcript[:2000])  # T5 limit

        return {
            'transcript': transcript,
            'summary': summary,
        }
    finally:
        os.unlink(tmp_path)  # Always delete temp file
