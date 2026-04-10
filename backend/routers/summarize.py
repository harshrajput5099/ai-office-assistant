# backend/routers/summarize.py
"""
Upgraded Summarize Router — Option 2: Both T5 and Mistral

Handles ALL document sizes including 1300-page textbooks:
  Small  (<50 pages)  → direct summarization
  Medium (50-150)     → chunked map-reduce
  Large  (150-400)    → split into parts
  Textbook (400+)     → chapter detection → per-chapter summary → merge

Supports: PDF, DOCX, DOC, PPTX, PPT, TXT
"""

import os
import time
import logging
from fastapi import APIRouter, UploadFile, File, HTTPException, Query

from utils.document_extractor import extract_text, SUPPORTED_EXTENSIONS
from utils.text_cleaner import clean_text
from utils.chunker import get_chunk_strategy, chunk_text, chunk_text_for_large_doc
from utils.textbook_processor import (
    extract_pages_with_text,
    detect_chapters,
    truncate_chapter_text,
)
from models.t5_model import summarize_chunk
import httpx

router = APIRouter()
logger = logging.getLogger(__name__)

# Pages above this threshold → use textbook/chapter strategy
TEXTBOOK_PAGE_THRESHOLD = 100


# ══════════════════════════════════════════════════════════
# MISTRAL — single call
# ══════════════════════════════════════════════════════════
async def _mistral_call(text: str, is_final: bool = False, context: str = "") -> str:
    """
    context: optional hint like "Chapter 3: Thermodynamics"
    is_final: True = structured output, False = plain condensed summary
    """
    if is_final:
        prompt = (
            "You are a professional textbook summarizer.\n"
            "Write a comprehensive structured summary with:\n"
            "**Overview:** what this textbook/document covers\n"
            "**Chapters Covered:** list each chapter and its main topic\n"
            "**Key Concepts:** most important concepts explained\n"
            "**Conclusions:** key takeaways a student should remember\n\n"
            f"Content:\n{text}"
        )
        num_predict = 1000
    elif context:
        prompt = (
            f"Summarize this textbook chapter in 4-6 sentences.\n"
            f"Chapter: {context}\n"
            f"Focus on: main concepts, key definitions, important examples.\n\n"
            f"Chapter content:\n{text}"
        )
        num_predict = 400
    else:
        prompt = (
            "Summarize the following text in 3-5 sentences. "
            "Cover all key points.\n\n"
            f"Text:\n{text}"
        )
        num_predict = 300

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                'http://localhost:11434/api/generate',
                json={
                    'model': 'mistral',
                    'prompt': prompt,
                    'stream': False,
                    'options': {'temperature': 0.3, 'num_predict': num_predict}
                },
                timeout=180.0
            )
        result = response.json()
        if 'response' in result:
            return result['response'].strip()
        elif 'message' in result:
            return result['message'].get('content', '').strip()
        else:
            raise HTTPException(500, f"Ollama unexpected format: {list(result.keys())}")

    except httpx.ConnectError:
        raise HTTPException(503, "Mistral not running. Run: ollama run mistral")
    except httpx.TimeoutException:
        raise HTTPException(504, "Mistral timed out. Restart Ollama.")


# ══════════════════════════════════════════════════════════
# T5 SUMMARIZER
# ══════════════════════════════════════════════════════════
def _t5_summarize(text: str, strategy: dict) -> str:
    chunks = chunk_text(text, chunk_size=strategy['chunk_size'])
    if strategy['strategy'] == 'hierarchical':
        summaries = [summarize_chunk(c) for c in chunks]
        return summarize_chunk(' '.join(summaries))
    else:
        batches = chunk_text_for_large_doc(text, chunk_size=strategy['chunk_size'])
        batch_summaries = []
        for i, batch in enumerate(batches):
            logger.info(f"T5 batch {i+1}/{len(batches)}")
            summaries = [summarize_chunk(c) for c in batch]
            batch_summaries.append(summarize_chunk(' '.join(summaries)))
        merged = ' '.join(batch_summaries)
        return summarize_chunk(merged) if len(merged.split()) > 500 else merged


# ══════════════════════════════════════════════════════════
# MISTRAL — normal map-reduce (small/medium docs)
# ══════════════════════════════════════════════════════════
async def _mistral_summarize_text(text: str, strategy: dict) -> str:
    doc_size   = strategy['doc_size']
    chunk_size = strategy['chunk_size']

    if doc_size in ('small', 'medium'):
        chunks = chunk_text(text, chunk_size=chunk_size)
        if len(chunks) == 1:
            return await _mistral_call(chunks[0], is_final=True)
        summaries = []
        for i, chunk in enumerate(chunks):
            logger.info(f"Mistral chunk {i+1}/{len(chunks)}")
            summaries.append(await _mistral_call(chunk))
        return await _mistral_call('\n\n'.join(summaries), is_final=True)
    else:
        batches = chunk_text_for_large_doc(text, chunk_size=chunk_size)
        batch_summaries = []
        for b_idx, batch in enumerate(batches):
            logger.info(f"Mistral batch {b_idx+1}/{len(batches)}")
            chunk_summaries = [
                await _mistral_call(chunk) for chunk in batch
            ]
            batch_summaries.append(
                await _mistral_call('\n\n'.join(chunk_summaries))
            )
        return await _mistral_call('\n\n'.join(batch_summaries), is_final=True)


# ══════════════════════════════════════════════════════════
# TEXTBOOK SUMMARIZER — chapter-by-chapter (400+ pages)
# ══════════════════════════════════════════════════════════
async def _summarize_textbook(
    file_bytes: bytes,
    use_mistral: bool,
) -> tuple[str, int, int, list]:
    """
    Smart chapter-based summarization for large textbooks.

    Steps:
    1. Extract all pages with text
    2. Detect chapter boundaries
    3. Summarize each chapter
    4. Merge into final structured summary

    Returns: (final_summary, page_count, chapter_count, chapter_details)
    """
    # STEP 1 — Extract pages
    logger.info("Step 1: Extracting pages...")
    pages = extract_pages_with_text(file_bytes)
    if not pages:
        raise ValueError("No text could be extracted. PDF may be scanned/image-based.")

    page_count = pages[-1]["page_num"] if pages else 0

    # STEP 2 — Detect chapters
    logger.info("Step 2: Detecting chapters...")
    chapters = detect_chapters(pages)

    logger.info(f"Found {len(chapters)} chapters across {page_count} pages")

    # STEP 3 — Summarize each chapter
    logger.info("Step 3: Summarizing each chapter...")
    chapter_summaries = []
    chapter_details   = []

    for ch in chapters:
        ch_title = ch['title']
        ch_text  = ch['text']
        ch_words = ch['word_count']

        logger.info(
            f"  Summarizing: '{ch_title[:40]}' "
            f"(pp.{ch['start_page']}-{ch['end_page']}, {ch_words} words)"
        )

        # Truncate to fit model context
        truncated = truncate_chapter_text(ch_text, max_words=3000)

        if use_mistral:
            ch_summary = await _mistral_call(
                truncated,
                is_final=False,
                context=ch_title
            )
        else:
            strategy   = get_chunk_strategy(truncated)
            ch_summary = _t5_summarize(truncated, strategy)

        chapter_summaries.append(
            f"**{ch_title}** (pages {ch['start_page']}-{ch['end_page']}):\n{ch_summary}"
        )
        chapter_details.append({
            "chapter": ch['chapter_num'],
            "title":   ch_title,
            "pages":   f"{ch['start_page']}-{ch['end_page']}",
            "words":   ch_words,
        })

    # STEP 4 — Final merge
    logger.info("Step 4: Merging chapter summaries...")
    all_chapter_summaries = '\n\n'.join(chapter_summaries)

    if use_mistral:
        # If too many chapters, truncate the merge input
        if len(all_chapter_summaries.split()) > 4000:
            all_chapter_summaries = ' '.join(
                all_chapter_summaries.split()[:4000]
            )
        final_summary = await _mistral_call(all_chapter_summaries, is_final=True)
    else:
        final_summary = summarize_chunk(all_chapter_summaries[:3000])

    return final_summary, page_count, len(chapters), chapter_details


# ══════════════════════════════════════════════════════════
# BENCHMARK
# ══════════════════════════════════════════════════════════
def _build_benchmark(
    filename, file_size_kb, page_count, word_count, chunk_count,
    strategy_used, model_used, extraction_time, summarization_time,
    summary_word_count, extra: dict = None
) -> dict:
    tokens   = int(word_count * 1.3)
    coverage = round(summary_word_count / max(word_count, 1) * 100, 2)

    if coverage < 1:    quality = "Very condensed — key topics captured"
    elif coverage < 5:  quality = "Good coverage — main points included"
    elif coverage < 15: quality = "Detailed coverage — comprehensive summary"
    else:               quality = "High coverage — full topic representation"

    benchmark = {
        "file_info": {
            "filename": filename, "file_size_kb": file_size_kb,
            "page_count": page_count, "word_count": word_count,
            "estimated_tokens": tokens,
        },
        "processing": {
            "strategy_used": strategy_used, "model_used": model_used,
            "chunk_count": chunk_count,
            "extraction_time_s": round(extraction_time, 3),
            "summarization_time_s": round(summarization_time, 3),
            "total_time_s": round(extraction_time + summarization_time, 3),
        },
        "output": {
            "summary_word_count": summary_word_count,
            "coverage_ratio_percent": coverage,
            "quality_note": quality,
        }
    }
    if extra:
        benchmark["extra"] = extra

    logger.info(
        f"\n{'='*50}\nBENCHMARK — {filename}\n"
        f"  Pages:{page_count} Strategy:{strategy_used} Model:{model_used}\n"
        f"  Time:{round(extraction_time+summarization_time,2)}s "
        f"Summary:{summary_word_count}w ({coverage}%)\n{'='*50}"
    )
    return benchmark


# ══════════════════════════════════════════════════════════
# QUICK PAGE COUNT (without full extraction)
# ══════════════════════════════════════════════════════════
def _quick_page_count(file_bytes: bytes) -> int:
    try:
        import pdfplumber
        with __import__('io').BytesIO(file_bytes) as buf:
            import io
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                return len(pdf.pages)
    except Exception:
        return 0


# ══════════════════════════════════════════════════════════
# MAIN ENDPOINT
# ══════════════════════════════════════════════════════════
@router.post('/summarize-document')
async def summarize_document(
    file: UploadFile = File(...),
    use_mistral: bool = Query(False, description="false=T5 fast | true=Mistral quality"),
    include_benchmark: bool = Query(True),
):
    """
    Universal document summarizer.

    Automatically selects strategy based on document size:
    - Small PDF (<100 pages)  → direct T5 or Mistral
    - Large PDF (100+ pages)  → chapter detection → per-chapter summary
    - DOCX / PPTX / TXT       → extract → chunk → summarize

    use_mistral=false → T5-small  (fast, always offline, 5-15s)
    use_mistral=true  → Mistral 7B (smart, needs Ollama, 15-25min for textbooks)
    """
    ext = os.path.splitext(file.filename.lower())[1]
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(
            400,
            f"Unsupported: '{ext}'. Allowed: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(400, "Empty file uploaded")

    try:
        total_start = time.time()

        # ── LARGE PDF → TEXTBOOK STRATEGY ─────────────────
        if ext == '.pdf':
            import io
            import pdfplumber
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                page_count = len(pdf.pages)

            if page_count >= TEXTBOOK_PAGE_THRESHOLD:
                logger.info(
                    f"Large PDF: {page_count} pages → "
                    f"using chapter-based strategy"
                )
                file_size_kb = round(len(file_bytes) / 1024, 2)
                summ_start   = time.time()

                final_summary, page_count, chapter_count, chapter_details = \
                    await _summarize_textbook(file_bytes, use_mistral)

                summ_time    = time.time() - summ_start
                model_used   = "mistral" if use_mistral else "t5-small"
                strategy_used = f"{'mistral' if use_mistral else 't5'}_chapter_merge"
                word_count   = page_count * 300  # rough estimate

                result = {
                    "summary":        final_summary,
                    "model_used":     model_used,
                    "document_type":  "PDF",
                    "chunk_count":    chapter_count,
                    "pages":          page_count,
                    "chapters_found": chapter_count,
                    "chapter_details": chapter_details,
                    "note": (
                        f"Textbook mode: {page_count} pages → "
                        f"{chapter_count} chapters summarized individually"
                    ),
                }

                if include_benchmark:
                    result["benchmark"] = _build_benchmark(
                        filename=file.filename, file_size_kb=file_size_kb,
                        page_count=page_count, word_count=word_count,
                        chunk_count=chapter_count,
                        strategy_used=strategy_used, model_used=model_used,
                        extraction_time=0, summarization_time=summ_time,
                        summary_word_count=len(final_summary.split()),
                        extra={"chapters": chapter_details},
                    )
                return result

        # ── NORMAL DOCUMENT (small PDF / DOCX / PPTX / TXT) ──
        extraction      = extract_text(file_bytes, file.filename)
        raw_text        = extraction["text"]
        page_count      = extraction["page_count"]
        file_size_kb    = extraction["file_size_kb"]
        extraction_time = extraction["extraction_time_s"]

        clean       = clean_text(raw_text)
        strategy    = get_chunk_strategy(clean)
        word_count  = strategy["word_count"]
        chunk_size  = strategy["chunk_size"]
        chunk_count = len(chunk_text(clean, chunk_size=chunk_size))

        summ_start = time.time()

        if use_mistral:
            final_summary = await _mistral_summarize_text(clean, strategy)
            model_used    = "mistral"
            strategy_used = f"mistral_{strategy['strategy']}"
        else:
            final_summary = _t5_summarize(clean, strategy)
            model_used    = "t5-small"
            strategy_used = f"t5_{strategy['strategy']}"

        summ_time = time.time() - summ_start

        result = {
            "summary":       final_summary,
            "model_used":    model_used,
            "document_type": ext.lstrip('.').upper(),
            "chunk_count":   chunk_count,
        }

        if include_benchmark:
            result["benchmark"] = _build_benchmark(
                filename=file.filename, file_size_kb=file_size_kb,
                page_count=page_count, word_count=word_count,
                chunk_count=chunk_count, strategy_used=strategy_used,
                model_used=model_used, extraction_time=extraction_time,
                summarization_time=summ_time,
                summary_word_count=len(final_summary.split()),
            )
        return result

    except ValueError as e:
        raise HTTPException(422, str(e))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(500, f"Processing error: {str(e)}")


# ══════════════════════════════════════════════════════════
# LEGACY ENDPOINT — keeps Flutter app working
# ══════════════════════════════════════════════════════════
@router.post('/summarize-pdf')
async def summarize_pdf(
    file: UploadFile = File(...),
    use_mistral: bool = Query(False),
):
    """Legacy PDF endpoint — backward compatible with existing Flutter app."""
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(400, 'Use /api/summarize-document for non-PDF files.')
    return await summarize_document(
        file=file,
        use_mistral=use_mistral,
        include_benchmark=False
    )




# backend/routers/summarize.py
"""
Upgraded Summarize Router — Option 2: Both T5 and Mistral

Handles ALL document sizes including 1300-page textbooks:
  Small  (<50 pages)  → direct summarization
  Medium (50-150)     → chunked map-reduce
  Large  (150-400)    → split into parts
  Textbook (400+)     → chapter detection → per-chapter summary → merge

Supports: PDF, DOCX, DOC, PPTX, PPT, TXT

ACCURACY CHANGES (vs previous version):
  1. Added detect_document_type() — model now knows journal vs conference vs textbook
  2. Added smart_merge() — hierarchical groups-of-3 merge instead of naive join
  3. _t5_summarize() now passes doc_type to every summarize_chunk() call
  4. _mistral_call() loads prompt from prompts/summarize_academic.txt when available
  5. Mistral temperature lowered: 0.3 → 0.1 (less creative = more factual)
  6. All endpoints now return doc_type field to Flutter
  7. All existing logic (textbook mode, benchmarks, map-reduce) fully preserved
"""

import os
import time
import logging
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, HTTPException, Query

from utils.document_extractor import extract_text, SUPPORTED_EXTENSIONS
from utils.text_cleaner import clean_text
from utils.chunker import get_chunk_strategy, chunk_text, chunk_text_for_large_doc
from utils.textbook_processor import (
    extract_pages_with_text,
    detect_chapters,
    truncate_chapter_text,
)

# ── ACCURACY ADDITION: doc type detector ──────────────────
# Tells the model whether it's reading a journal article,
# conference paper, or textbook — fixes wrong label problem
from utils.doc_type_detector import detect_document_type

from models.t5_model import summarize_chunk
import httpx

router = APIRouter()
logger = logging.getLogger(__name__)

# Pages above this threshold → use textbook/chapter strategy
TEXTBOOK_PAGE_THRESHOLD = 100


# ══════════════════════════════════════════════════════════
# ACCURACY ADDITION: smart_merge
# Replaces naive ' '.join(summaries) with hierarchical merge.
# Groups of 3 → merge each group → merge group results.
# This gives the final T5 call digestible input instead of
# a wall of text from dozens of chunks.
# ══════════════════════════════════════════════════════════
def smart_merge(chunk_summaries: list, doc_type: str = "document") -> str:
    """
    Smarter merge strategy for T5 chunk summaries.

    <= 4 chunks : merge all at once (same as before, no change)
    > 4 chunks  : merge in groups of 3 first, then merge results
                  → prevents T5 from getting overwhelmed by long input

    doc_type is passed through so each T5 call knows what kind
    of document it's summarizing.
    """
    if len(chunk_summaries) <= 4:
        merged = ' '.join(chunk_summaries)
        return summarize_chunk(merged, doc_type)

    # Groups of 3 → intermediate summaries
    group_summaries = []
    for i in range(0, len(chunk_summaries), 3):
        group_text = ' '.join(chunk_summaries[i:i + 3])
        group_summaries.append(summarize_chunk(group_text, doc_type))

    # Final merge of group summaries
    final = ' '.join(group_summaries)
    return summarize_chunk(final, doc_type)


# ══════════════════════════════════════════════════════════
# ACCURACY ADDITION: load prompt helper
# Loads structured prompt from prompts/ folder if available.
# Falls back to inline prompt if file not found.
# ══════════════════════════════════════════════════════════
def _load_prompt(filename: str, **kwargs) -> str:
    """
    Loads a prompt template from backend/prompts/ folder.
    Substitutes {placeholders} with kwargs.
    Returns fallback string if file not found.
    """
    try:
        template = Path(f'prompts/{filename}').read_text(encoding='utf-8')
        return template.format(**kwargs)
    except FileNotFoundError:
        logger.warning(f"Prompt file not found: prompts/{filename} — using fallback")
        return None
    except KeyError as e:
        logger.warning(f"Prompt template missing key {e} — using fallback")
        return None


# ══════════════════════════════════════════════════════════
# MISTRAL — single call
# ACCURACY CHANGES:
#   - temperature lowered from 0.3 → 0.1 (more factual)
#   - is_final=True now loads from prompts/summarize_academic.txt
#   - doc_type passed in so prompt can reference it
# ══════════════════════════════════════════════════════════
async def _mistral_call(
    text: str,
    is_final: bool = False,
    context: str = "",
    doc_type: str = "document"     # ACCURACY ADDITION
) -> str:
    """
    context: optional hint like "Chapter 3: Thermodynamics"
    is_final: True = structured output, False = plain condensed summary
    doc_type: detected document type — passed to prompt template
    """
    if is_final:
        # ACCURACY CHANGE: try loading from prompt file first
        prompt = _load_prompt('summarize_academic.txt', text=text, doc_type=doc_type)

        if prompt is None:
            # Fallback to inline prompt (same as original but with doc_type)
            prompt = (
                f"You are a professional {doc_type} summarizer.\n"
                "Write a comprehensive structured summary with:\n"
                "**Overview:** what this document covers\n"
                "**Key Concepts:** most important concepts explained\n"
                "**Conclusions:** key takeaways\n\n"
                f"Content:\n{text}"
            )
        num_predict = 1000

    elif context:
        prompt = (
            f"Summarize this textbook chapter in 4-6 sentences.\n"
            f"Chapter: {context}\n"
            f"Focus on: main concepts, key definitions, important examples.\n\n"
            f"Chapter content:\n{text}"
        )
        num_predict = 400

    else:
        # Chunk-level call — try the chunk prompt file
        prompt = _load_prompt('summarize_chunk.txt', text=text, doc_type=doc_type)

        if prompt is None:
            prompt = (
                f"Summarize the following {doc_type} section in 3-5 sentences. "
                "Cover all key points.\n\n"
                f"Text:\n{text}"
            )
        num_predict = 300

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                'http://localhost:11434/api/generate',
                json={
                    'model': 'mistral',
                    'prompt': prompt,
                    'stream': False,
                    'options': {
                        'temperature': 0.1,    # ACCURACY CHANGE: was 0.3
                        'top_p': 0.9,
                        'num_predict': num_predict
                    }
                },
                timeout=180.0
            )
        result = response.json()
        if 'response' in result:
            return result['response'].strip()
        elif 'message' in result:
            return result['message'].get('content', '').strip()
        else:
            raise HTTPException(500, f"Ollama unexpected format: {list(result.keys())}")

    except httpx.ConnectError:
        raise HTTPException(503, "Mistral not running. Run: ollama run mistral")
    except httpx.TimeoutException:
        raise HTTPException(504, "Mistral timed out. Restart Ollama.")


# ══════════════════════════════════════════════════════════
# T5 SUMMARIZER
# ACCURACY CHANGES:
#   - doc_type parameter added throughout
#   - summarize_chunk() calls now pass doc_type
#   - hierarchical path uses smart_merge instead of naive join
# ══════════════════════════════════════════════════════════
def _t5_summarize(text: str, strategy: dict, doc_type: str = "document") -> str:
    """
    ACCURACY CHANGE: doc_type is now passed to every summarize_chunk() call
    and smart_merge() is used instead of naive ' '.join() + single T5 call.
    map_reduce path unchanged in structure, just passes doc_type through.
    """
    chunks = chunk_text(text, chunk_size=strategy['chunk_size'])

    if strategy['strategy'] == 'hierarchical':
        # ACCURACY CHANGE: pass doc_type, use smart_merge
        chunk_summaries = [summarize_chunk(c, doc_type) for c in chunks]
        return smart_merge(chunk_summaries, doc_type)

    else:
        # map_reduce path — unchanged in structure, doc_type added
        batches = chunk_text_for_large_doc(text, chunk_size=strategy['chunk_size'])
        batch_summaries = []
        for i, batch in enumerate(batches):
            logger.info(f"T5 batch {i+1}/{len(batches)}")
            # ACCURACY CHANGE: pass doc_type to each chunk
            chunk_summaries = [summarize_chunk(c, doc_type) for c in batch]
            # ACCURACY CHANGE: use smart_merge for batch merge
            batch_summaries.append(smart_merge(chunk_summaries, doc_type))

        merged = ' '.join(batch_summaries)
        # Final merge — keep existing logic
        return summarize_chunk(merged, doc_type) if len(merged.split()) > 500 else merged


# ══════════════════════════════════════════════════════════
# MISTRAL — normal map-reduce (small/medium docs)
# ACCURACY CHANGES:
#   - doc_type parameter added and passed to _mistral_call()
# ══════════════════════════════════════════════════════════
async def _mistral_summarize_text(
    text: str,
    strategy: dict,
    doc_type: str = "document"    # ACCURACY ADDITION
) -> str:
    doc_size   = strategy['doc_size']
    chunk_size = strategy['chunk_size']

    if doc_size in ('small', 'medium'):
        chunks = chunk_text(text, chunk_size=chunk_size)
        if len(chunks) == 1:
            # ACCURACY CHANGE: pass doc_type
            return await _mistral_call(chunks[0], is_final=True, doc_type=doc_type)

        summaries = []
        for i, chunk in enumerate(chunks):
            logger.info(f"Mistral chunk {i+1}/{len(chunks)}")
            # ACCURACY CHANGE: pass doc_type to each chunk call
            summaries.append(await _mistral_call(chunk, doc_type=doc_type))

        # ACCURACY CHANGE: pass doc_type to final merge call
        return await _mistral_call(
            '\n\n'.join(summaries), is_final=True, doc_type=doc_type
        )

    else:
        # map_reduce path — doc_type added throughout
        batches = chunk_text_for_large_doc(text, chunk_size=chunk_size)
        batch_summaries = []
        for b_idx, batch in enumerate(batches):
            logger.info(f"Mistral batch {b_idx+1}/{len(batches)}")
            chunk_summaries = [
                await _mistral_call(chunk, doc_type=doc_type) for chunk in batch
            ]
            batch_summaries.append(
                await _mistral_call(
                    '\n\n'.join(chunk_summaries), doc_type=doc_type
                )
            )
        return await _mistral_call(
            '\n\n'.join(batch_summaries), is_final=True, doc_type=doc_type
        )


# ══════════════════════════════════════════════════════════
# TEXTBOOK SUMMARIZER — chapter-by-chapter (400+ pages)
# ACCURACY CHANGES:
#   - doc_type detected once and passed to all _mistral_call()
#     and _t5_summarize() calls
#   - Returns doc_type so endpoint can include it in response
# ══════════════════════════════════════════════════════════
async def _summarize_textbook(
    file_bytes: bytes,
    use_mistral: bool,
) -> tuple[str, int, int, list, str]:
    """
    Smart chapter-based summarization for large textbooks.

    Steps:
    1. Extract all pages with text
    2. Detect chapter boundaries
    3. Summarize each chapter
    4. Merge into final structured summary

    ACCURACY CHANGE: now returns doc_type as 5th element of tuple.
    Returns: (final_summary, page_count, chapter_count, chapter_details, doc_type)
    """
    # STEP 1 — Extract pages
    logger.info("Step 1: Extracting pages...")
    pages = extract_pages_with_text(file_bytes)
    if not pages:
        raise ValueError("No text could be extracted. PDF may be scanned/image-based.")

    page_count = pages[-1]["page_num"] if pages else 0

    # ACCURACY ADDITION: detect doc type from first few pages
    sample_text = ' '.join(p.get('text', '') for p in pages[:10])
    doc_type = detect_document_type(sample_text)
    logger.info(f"Detected document type: {doc_type}")

    # STEP 2 — Detect chapters
    logger.info("Step 2: Detecting chapters...")
    chapters = detect_chapters(pages)
    logger.info(f"Found {len(chapters)} chapters across {page_count} pages")

    # STEP 3 — Summarize each chapter
    logger.info("Step 3: Summarizing each chapter...")
    chapter_summaries = []
    chapter_details   = []

    for ch in chapters:
        ch_title = ch['title']
        ch_text  = ch['text']
        ch_words = ch['word_count']

        logger.info(
            f"  Summarizing: '{ch_title[:40]}' "
            f"(pp.{ch['start_page']}-{ch['end_page']}, {ch_words} words)"
        )

        truncated = truncate_chapter_text(ch_text, max_words=3000)

        if use_mistral:
            ch_summary = await _mistral_call(
                truncated,
                is_final=False,
                context=ch_title,
                doc_type=doc_type    # ACCURACY ADDITION
            )
        else:
            strategy   = get_chunk_strategy(truncated)
            # ACCURACY ADDITION: pass doc_type
            ch_summary = _t5_summarize(truncated, strategy, doc_type=doc_type)

        chapter_summaries.append(
            f"**{ch_title}** (pages {ch['start_page']}-{ch['end_page']}):\n{ch_summary}"
        )
        chapter_details.append({
            "chapter": ch['chapter_num'],
            "title":   ch_title,
            "pages":   f"{ch['start_page']}-{ch['end_page']}",
            "words":   ch_words,
        })

    # STEP 4 — Final merge
    logger.info("Step 4: Merging chapter summaries...")
    all_chapter_summaries = '\n\n'.join(chapter_summaries)

    if use_mistral:
        if len(all_chapter_summaries.split()) > 4000:
            all_chapter_summaries = ' '.join(
                all_chapter_summaries.split()[:4000]
            )
        # ACCURACY ADDITION: pass doc_type to final call
        final_summary = await _mistral_call(
            all_chapter_summaries, is_final=True, doc_type=doc_type
        )
    else:
        # ACCURACY ADDITION: pass doc_type
        final_summary = summarize_chunk(all_chapter_summaries[:3000], doc_type)

    # ACCURACY CHANGE: return doc_type as 5th element
    return final_summary, page_count, len(chapters), chapter_details, doc_type


# ══════════════════════════════════════════════════════════
# BENCHMARK — UNCHANGED
# ══════════════════════════════════════════════════════════
def _build_benchmark(
    filename, file_size_kb, page_count, word_count, chunk_count,
    strategy_used, model_used, extraction_time, summarization_time,
    summary_word_count, extra: dict = None
) -> dict:
    tokens   = int(word_count * 1.3)
    coverage = round(summary_word_count / max(word_count, 1) * 100, 2)

    if coverage < 1:    quality = "Very condensed — key topics captured"
    elif coverage < 5:  quality = "Good coverage — main points included"
    elif coverage < 15: quality = "Detailed coverage — comprehensive summary"
    else:               quality = "High coverage — full topic representation"

    benchmark = {
        "file_info": {
            "filename": filename, "file_size_kb": file_size_kb,
            "page_count": page_count, "word_count": word_count,
            "estimated_tokens": tokens,
        },
        "processing": {
            "strategy_used": strategy_used, "model_used": model_used,
            "chunk_count": chunk_count,
            "extraction_time_s": round(extraction_time, 3),
            "summarization_time_s": round(summarization_time, 3),
            "total_time_s": round(extraction_time + summarization_time, 3),
        },
        "output": {
            "summary_word_count": summary_word_count,
            "coverage_ratio_percent": coverage,
            "quality_note": quality,
        }
    }
    if extra:
        benchmark["extra"] = extra

    logger.info(
        f"\n{'='*50}\nBENCHMARK — {filename}\n"
        f"  Pages:{page_count} Strategy:{strategy_used} Model:{model_used}\n"
        f"  Time:{round(extraction_time+summarization_time,2)}s "
        f"Summary:{summary_word_count}w ({coverage}%)\n{'='*50}"
    )
    return benchmark


# ══════════════════════════════════════════════════════════
# QUICK PAGE COUNT — UNCHANGED
# ══════════════════════════════════════════════════════════
def _quick_page_count(file_bytes: bytes) -> int:
    try:
        import io
        import pdfplumber
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            return len(pdf.pages)
    except Exception:
        return 0


# ══════════════════════════════════════════════════════════
# MAIN ENDPOINT
# ACCURACY CHANGES:
#   - detect_document_type() called on extracted text
#   - doc_type passed to _t5_summarize() and _mistral_summarize_text()
#   - doc_type returned in response JSON
#   - _summarize_textbook() now returns 5-tuple (added doc_type)
# ══════════════════════════════════════════════════════════
@router.post('/summarize-document')
async def summarize_document(
    file: UploadFile = File(...),
    use_mistral: bool = Query(False, description="false=T5 fast | true=Mistral quality"),
    include_benchmark: bool = Query(True),
):
    """
    Universal document summarizer.

    Automatically selects strategy based on document size:
    - Small PDF (<100 pages)  → direct T5 or Mistral
    - Large PDF (100+ pages)  → chapter detection → per-chapter summary
    - DOCX / PPTX / TXT       → extract → chunk → summarize

    use_mistral=false → T5-small  (fast, always offline, 5-15s)
    use_mistral=true  → Mistral 7B (smart, needs Ollama, 15-25min for textbooks)
    """
    ext = os.path.splitext(file.filename.lower())[1]
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(
            400,
            f"Unsupported: '{ext}'. Allowed: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(400, "Empty file uploaded")

    try:
        total_start = time.time()

        # ── LARGE PDF → TEXTBOOK STRATEGY ─────────────────
        if ext == '.pdf':
            import io
            import pdfplumber
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                page_count = len(pdf.pages)

            if page_count >= TEXTBOOK_PAGE_THRESHOLD:
                logger.info(
                    f"Large PDF: {page_count} pages → "
                    f"using chapter-based strategy"
                )
                file_size_kb = round(len(file_bytes) / 1024, 2)
                summ_start   = time.time()

                # ACCURACY CHANGE: unpack 5-tuple (added doc_type)
                final_summary, page_count, chapter_count, chapter_details, doc_type = \
                    await _summarize_textbook(file_bytes, use_mistral)

                summ_time     = time.time() - summ_start
                model_used    = "mistral" if use_mistral else "t5-small"
                strategy_used = f"{'mistral' if use_mistral else 't5'}_chapter_merge"
                word_count    = page_count * 300  # rough estimate

                result = {
                    "summary":         final_summary,
                    "doc_type":        doc_type,         # ACCURACY ADDITION
                    "model_used":      model_used,
                    "document_type":   "PDF",
                    "chunk_count":     chapter_count,
                    "pages":           page_count,
                    "chapters_found":  chapter_count,
                    "chapter_details": chapter_details,
                    "note": (
                        f"Textbook mode: {page_count} pages → "
                        f"{chapter_count} chapters summarized individually"
                    ),
                }

                if include_benchmark:
                    result["benchmark"] = _build_benchmark(
                        filename=file.filename, file_size_kb=file_size_kb,
                        page_count=page_count, word_count=word_count,
                        chunk_count=chapter_count,
                        strategy_used=strategy_used, model_used=model_used,
                        extraction_time=0, summarization_time=summ_time,
                        summary_word_count=len(final_summary.split()),
                        extra={"chapters": chapter_details},
                    )
                return result

        # ── NORMAL DOCUMENT (small PDF / DOCX / PPTX / TXT) ──
        extraction      = extract_text(file_bytes, file.filename)
        raw_text        = extraction["text"]
        page_count      = extraction["page_count"]
        file_size_kb    = extraction["file_size_kb"]
        extraction_time = extraction["extraction_time_s"]

        clean      = clean_text(raw_text)
        strategy   = get_chunk_strategy(clean)
        word_count = strategy["word_count"]
        chunk_size = strategy["chunk_size"]

        # ACCURACY ADDITION: detect document type from cleaned text
        doc_type   = detect_document_type(clean)
        logger.info(f"Detected document type: {doc_type}")

        chunk_count = len(chunk_text(clean, chunk_size=chunk_size))

        summ_start = time.time()

        if use_mistral:
            # ACCURACY CHANGE: pass doc_type to Mistral summarizer
            final_summary = await _mistral_summarize_text(clean, strategy, doc_type=doc_type)
            model_used    = "mistral"
            strategy_used = f"mistral_{strategy['strategy']}"
        else:
            # ACCURACY CHANGE: pass doc_type to T5 summarizer
            final_summary = _t5_summarize(clean, strategy, doc_type=doc_type)
            model_used    = "t5-small"
            strategy_used = f"t5_{strategy['strategy']}"

        summ_time = time.time() - summ_start

        result = {
            "summary":       final_summary,
            "doc_type":      doc_type,      # ACCURACY ADDITION
            "model_used":    model_used,
            "document_type": ext.lstrip('.').upper(),
            "chunk_count":   chunk_count,
        }

        if include_benchmark:
            result["benchmark"] = _build_benchmark(
                filename=file.filename, file_size_kb=file_size_kb,
                page_count=page_count, word_count=word_count,
                chunk_count=chunk_count, strategy_used=strategy_used,
                model_used=model_used, extraction_time=extraction_time,
                summarization_time=summ_time,
                summary_word_count=len(final_summary.split()),
            )
        return result

    except ValueError as e:
        raise HTTPException(422, str(e))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise HTTPException(500, f"Processing error: {str(e)}")


# ══════════════════════════════════════════════════════════
# LEGACY ENDPOINT — keeps Flutter app working
# ACCURACY CHANGE: now returns doc_type in response
# ══════════════════════════════════════════════════════════
@router.post('/summarize-pdf')
async def summarize_pdf(
    file: UploadFile = File(...),
    use_mistral: bool = Query(False),
):
    """Legacy PDF endpoint — backward compatible with existing Flutter app."""
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(400, 'Use /api/summarize-document for non-PDF files.')
    return await summarize_document(
        file=file,
        use_mistral=use_mistral,
        include_benchmark=False
    )