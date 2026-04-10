from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from utils.export_generator import generate_word_doc, generate_pdf

router = APIRouter()


class ExportRequest(BaseModel):
    summary: str
    filename: str = 'document.pdf'   # original PDF filename from Flutter


# ── Word Export ──────────────────────────────────
@router.post('/export/word')
def export_word(req: ExportRequest):
    '''Generates a formatted Word document from the summary.'''
    try:
        file_bytes = generate_word_doc(
            summary=req.summary,
            filename=req.filename,
        )
        return Response(
            content=file_bytes,
            media_type='application/vnd.openxmlformats-officedocument'
                       '.wordprocessingml.document',
            headers={
                'Content-Disposition': 'attachment; filename="summary.docx"'
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Word export failed: {str(e)}')


# ── PDF Export ───────────────────────────────────
@router.post('/export/pdf')
def export_pdf(req: ExportRequest):
    '''Generates a clean PDF from the summary.'''
    try:
        file_bytes = generate_pdf(
            summary=req.summary,
            filename=req.filename,
        )
        return Response(
            content=file_bytes,
            media_type='application/pdf',
            headers={
                'Content-Disposition': 'attachment; filename="summary.pdf"'
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'PDF export failed: {str(e)}')


# NOTE: Plain Text (.txt) export is handled entirely in Flutter
# No backend endpoint needed for .txt
