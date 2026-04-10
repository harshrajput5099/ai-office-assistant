# backend/utils/textbook_processor.py
"""
Smart Textbook Processor
Designed for large textbooks (500-1500 pages)

Strategy:
1. Extract text page by page
2. Detect chapter boundaries using heading patterns
3. Summarize each chapter individually with Mistral
4. Merge all chapter summaries into final structured output

This is much faster than page-by-page processing:
  1300 pages / 20 chapters = 20 Mistral calls (not 260!)
  Time: 15-25 minutes instead of 104 minutes
"""

import io
import re
import logging
import time

logger = logging.getLogger(__name__)

# ─── CHAPTER HEADING PATTERNS ─────────────────────────────
# Matches common textbook chapter formats like:
# "Chapter 1", "CHAPTER 1", "Chapter 1:", "1. Introduction",
# "UNIT 1", "Part I", "Section 1", "MODULE 1"
CHAPTER_PATTERNS = [
    r'^chapter\s+\d+',
    r'^chapter\s+[ivxlcdm]+',       # Roman numerals
    r'^CHAPTER\s+\d+',
    r'^unit\s+\d+',
    r'^UNIT\s+\d+',
    r'^part\s+\d+',
    r'^part\s+[ivxlcdm]+',
    r'^PART\s+\d+',
    r'^section\s+\d+',
    r'^module\s+\d+',
    r'^MODULE\s+\d+',
    r'^\d+\.\s+[A-Z][a-zA-Z\s]{3,}',  # "1. Introduction to..."
    r'^[A-Z][A-Z\s]{5,}$',             # ALL CAPS headings
]


def is_chapter_heading(text: str) -> bool:
    """Check if a line looks like a chapter heading."""
    text = text.strip()
    if len(text) < 3 or len(text) > 100:
        return False
    for pattern in CHAPTER_PATTERNS:
        if re.match(pattern, text, re.IGNORECASE):
            return True
    return False


def extract_pages_with_text(file_bytes: bytes) -> list[dict]:
    """
    Extract text from each page of the PDF.
    Returns list of {page_num, text} dicts.
    Skips blank/image-only pages.
    """
    try:
        import pdfplumber
    except ImportError:
        raise ImportError("Run: pip install pdfplumber")

    pages = []
    with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
        total = len(pdf.pages)
        logger.info(f"Extracting {total} pages...")

        for i, page in enumerate(pdf.pages):
            if i % 100 == 0:
                logger.info(f"  Extracting page {i+1}/{total}...")
            text = page.extract_text()
            if text and len(text.strip()) > 20:
                pages.append({
                    "page_num": i + 1,
                    "text": text.strip()
                })

    logger.info(f"Extracted {len(pages)} pages with text (out of {total})")
    return pages


def detect_chapters(pages: list[dict]) -> list[dict]:
    """
    Groups pages into chapters by detecting headings.
    Returns list of chapters, each with:
    {chapter_num, title, start_page, end_page, text}

    If no chapters detected (no headings found),
    falls back to equal-size sections of 60 pages each.
    """
    chapters = []
    current_chapter = None
    chapter_num = 0

    for page in pages:
        lines = page["text"].split('\n')
        first_lines = [l.strip() for l in lines[:5] if l.strip()]

        # Check if this page starts a new chapter
        is_new_chapter = False
        chapter_title  = ""

        for line in first_lines:
            if is_chapter_heading(line):
                is_new_chapter = True
                chapter_title  = line
                break

        if is_new_chapter:
            # Save previous chapter
            if current_chapter:
                chapters.append(current_chapter)

            chapter_num += 1
            current_chapter = {
                "chapter_num": chapter_num,
                "title":       chapter_title or f"Chapter {chapter_num}",
                "start_page":  page["page_num"],
                "end_page":    page["page_num"],
                "text":        page["text"],
                "word_count":  len(page["text"].split()),
            }
        else:
            if current_chapter:
                current_chapter["text"]       += "\n\n" + page["text"]
                current_chapter["end_page"]    = page["page_num"]
                current_chapter["word_count"] += len(page["text"].split())
            else:
                # Pages before first chapter heading → intro section
                chapter_num += 1
                current_chapter = {
                    "chapter_num": chapter_num,
                    "title":       "Introduction / Preface",
                    "start_page":  page["page_num"],
                    "end_page":    page["page_num"],
                    "text":        page["text"],
                    "word_count":  len(page["text"].split()),
                }

    # Save last chapter
    if current_chapter:
        chapters.append(current_chapter)

    # ── Fallback: no chapters detected ────────────────────
    if len(chapters) <= 1:
        logger.warning("No chapter headings detected — falling back to 60-page sections")
        chapters = _split_into_sections(pages, pages_per_section=60)

    logger.info(f"Detected {len(chapters)} chapters/sections")
    for c in chapters:
        logger.info(
            f"  Ch.{c['chapter_num']:2d} '{c['title'][:40]}' "
            f"pp.{c['start_page']}-{c['end_page']} "
            f"({c['word_count']} words)"
        )

    return chapters


def _split_into_sections(pages: list[dict], pages_per_section: int = 60) -> list[dict]:
    """Fallback: split pages into equal sections when no chapters detected."""
    sections = []
    section_num = 0

    for i in range(0, len(pages), pages_per_section):
        section_pages = pages[i:i + pages_per_section]
        section_num += 1
        combined_text = '\n\n'.join(p["text"] for p in section_pages)
        sections.append({
            "chapter_num": section_num,
            "title":       f"Section {section_num} (pages {section_pages[0]['page_num']}-{section_pages[-1]['page_num']})",
            "start_page":  section_pages[0]["page_num"],
            "end_page":    section_pages[-1]["page_num"],
            "text":        combined_text,
            "word_count":  len(combined_text.split()),
        })

    return sections


def truncate_chapter_text(text: str, max_words: int = 3000) -> str:
    """
    Truncates chapter text to fit Mistral context.
    Keeps beginning (60%) and end (40%) — most important parts of a chapter.
    max_words=3000 keeps us safely under Mistral's 8k token limit.
    """
    words = text.split()
    if len(words) <= max_words:
        return text

    keep_start = int(max_words * 0.6)
    keep_end   = int(max_words * 0.4)

    start_text = ' '.join(words[:keep_start])
    end_text   = ' '.join(words[-keep_end:])

    truncated = f"{start_text}\n\n[...content truncated...]\n\n{end_text}"
    logger.info(f"Chapter truncated: {len(words)} → {max_words} words")
    return truncated