# backend/routers/email_gen.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx
import os

router = APIRouter()

class EmailRequest(BaseModel):
    purpose: str
    recipient_role: str
    tone: str = 'formal'
    key_points: list[str]
    required_response: str

PROMPT_DIR = os.path.join(os.path.dirname(__file__), '..', 'prompts')

def load_prompt(tone: str) -> str:  # Can choose the Tone of email 
    tone_map = {
        'formal':     'email_formal.txt',
        'semiformal': 'email_semiformal.txt',
        'friendly':   'email_friendly.txt',
    }
    filename = tone_map.get(tone.lower(), 'email_formal.txt')
    path = os.path.join(PROMPT_DIR, filename)
    try:
        with open(path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return (
            'Write a {tone} email. Purpose: {purpose}. '
            'Recipient: {recipient_role}. Points: {key_points}. '
            'Required response: {required_response}'
        )

@router.post('/generate-email')
async def generate_email(req: EmailRequest):
    key_points_str = '\n'.join(f'- {p}' for p in req.key_points)

    template = load_prompt(req.tone)
    prompt = template.format(
        purpose=req.purpose,
        recipient_role=req.recipient_role,
        key_points=key_points_str,
        required_response=req.required_response
    )

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                'http://localhost:11434/api/generate',
                json={'model': 'mistral', 'prompt': prompt, 'stream': False},
                timeout=120.0
            )
        response.raise_for_status()
    except httpx.TimeoutException:
        raise HTTPException(status_code=504,
            detail='Mistral timed out. Make sure Ollama is running: ollama serve')
    except httpx.ConnectError:
        raise HTTPException(status_code=503,
            detail='Cannot connect to Ollama. Run: ollama serve')

    result = response.json().get('response', '').strip()
    if not result:
        raise HTTPException(status_code=500, detail='Mistral returned empty response.')

    return {'email': result, 'tone': req.tone}