from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx

router = APIRouter()

class EmailRequest(BaseModel):
    purpose: str
    recipient_role: str
    tone: str = 'formal'
    key_points: list[str]
    call_to_action: str

@router.post('/generate-email')
async def generate_email(req: EmailRequest):
    points = chr(10).join(f'- {p}' for p in req.key_points)
    prompt = f'''
    Write a {req.tone} professional email.
    Purpose: {req.purpose}
    Recipient: {req.recipient_role}
    Key points: {points}
    Required action: {req.call_to_action}
    Format: Subject line then email body.
    '''

    async with httpx.AsyncClient() as client:
        response = await client.post(
            'http://localhost:11434/api/generate',
            json={'model': 'mistral', 'prompt': prompt, 'stream': False},
            timeout=60.0
        )

    result = response.json()['response']
    return {'email': result}
