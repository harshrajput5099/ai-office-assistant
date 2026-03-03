from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from utils.pdf_extractor import extract_text_from_pdf
from utils.text_cleaner import clean_text
from utils.chunker import chunk_text
from models.t5_model import summarize_chunk
import httpx

router = APIRouter()

async def summarize_with_mistral(text: str) -> str:
    prompt = f'''
    Analyze this document and return a detailed summary with:
    - purpose: what is this document about
    - key_points: list of main points
    - decisions: list of any decisions or conclusions
    - action_items: list of any tasks or recommendations
    Document: {text[:3000]}
    '''
    async with httpx.AsyncClient() as client:
        response = await client.post(
            'http://localhost:11434/api/generate',
            json={'model': 'mistral', 'prompt': prompt, 'stream': False},
            timeout=60.0
        )
    return response.json()['response']

@router.post('/summarize-pdf')
async def summarize_pdf(
    file: UploadFile = File(...),
    use_mistral: bool = Query(False, description="Use Mistral for better quality")
):
    if not file.filename.endswith('.pdf'):
        raise HTTPException(400, 'Only PDF files are accepted')

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(400, 'Empty file uploaded')

    try:
        raw_text = extract_text_from_pdf(file_bytes)
        clean = clean_text(raw_text)
        chunks = chunk_text(clean)

        if use_mistral:
            merged = ' '.join(chunks)
            final_summary = await summarize_with_mistral(merged)
            return {
                'summary': final_summary,
                'chunk_count': len(chunks),
                'model_used': 'mistral'
            }
        else:
            chunk_summaries = [summarize_chunk(c) for c in chunks]
            merged = ' '.join(chunk_summaries)
            final_summary = summarize_chunk(merged)
            return {
                'summary': final_summary,
                'chunk_count': len(chunks),
                'model_used': 't5-small'
            }

    except ValueError as e:
        raise HTTPException(422, str(e))
    except httpx.ConnectError:
        raise HTTPException(503, 'Mistral not running. Start Ollama with: ollama run mistral')
    except Exception as e:
        raise HTTPException(500, f'Processing error: {str(e)}')
