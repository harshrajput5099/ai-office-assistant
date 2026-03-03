import re

def clean_text(raw_text: str) -> str:
    text = re.sub(r'\n{3,}', '\n\n', raw_text)   # max 2 newlines
    text = re.sub(r'[ \t]+', ' ', text)           # collapse spaces
    text = re.sub(r'[^\x00-\x7F]+', ' ', text)   # remove non-ASCII
    text = text.strip()
    return text
