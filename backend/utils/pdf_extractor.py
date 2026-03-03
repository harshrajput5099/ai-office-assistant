import pdfplumber

def extract_text_from_pdf(file_bytes: bytes) -> str:
    """
    Takes PDF as bytes (from FastAPI upload),
    returns extracted plain text.
    """
    import io
    text_parts = []

    with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text_parts.append(page_text)

    if not text_parts:
        raise ValueError('No text found. PDF may be scanned image.')

    return '\n\n'.join(text_parts)
