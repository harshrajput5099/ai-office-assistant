# backend/utils/pdf_splitter.py
"""
PDF Splitter utility.
Splits large PDFs into sections before summarization.
Prevents timeout on 300+ page documents.

Strategy:
  Under 50 pages  → process directly
  50-150 pages    → split into 2 parts, summarize each, merge
  150-400 pages   → split into 4 parts, summarize each, merge
  400+ pages      → split into 8 parts, summarize each, merge
"""

import io
import logging

logger = logging.getLogger(__name__)


def get_pdf_page_count(file_bytes: bytes) -> int:
    """Quick page count without full extraction."""
    try:
        import pdfplumber
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            return len(pdf.pages)
    except Exception:
        return 0


def split_pdf_bytes(file_bytes: bytes, max_pages_per_part: int = 50) -> list[bytes]:
    """
    Splits a PDF into chunks of max_pages_per_part pages each.
    Returns list of PDF byte strings, one per part.
    """
    try:
        import pypdf
    except ImportError:
        raise ImportError("Run: pip install pypdf")

    reader = pypdf.PdfReader(io.BytesIO(file_bytes))
    total_pages = len(reader.pages)

    if total_pages <= max_pages_per_part:
        return [file_bytes]  # No split needed

    parts = []
    for start in range(0, total_pages, max_pages_per_part):
        end = min(start + max_pages_per_part, total_pages)
        writer = pypdf.PdfWriter()
        for page_num in range(start, end):
            writer.add_page(reader.pages[page_num])
        buf = io.BytesIO()
        writer.write(buf)
        parts.append(buf.getvalue())
        logger.info(f"PDF part: pages {start+1}-{end} ({end-start} pages)")

    logger.info(f"Split {total_pages}-page PDF into {len(parts)} parts")
    return parts


def get_split_strategy(page_count: int) -> dict:
    """Returns recommended split strategy based on page count."""
    if page_count <= 50:
        return {"should_split": False, "max_pages_per_part": page_count, "parts": 1}
    elif page_count <= 150:
        return {"should_split": True, "max_pages_per_part": 75, "parts": 2}
    elif page_count <= 400:
        return {"should_split": True, "max_pages_per_part": 100, "parts": 4}
    else:
        return {"should_split": True, "max_pages_per_part": 60, "parts": 8}