def chunk_text(text: str, chunk_size: int = 600) -> list[str]:
    """
    Splits text into chunks of approximately chunk_size words.
    Always splits on sentence boundaries to preserve meaning.
    """
    sentences = text.replace('\n', ' ').split('. ')
    chunks = []
    current_chunk = []
    current_word_count = 0

    for sentence in sentences:
        words = sentence.split()
        if current_word_count + len(words) > chunk_size and current_chunk:
            chunks.append('. '.join(current_chunk) + '.')
            current_chunk = [sentence]
            current_word_count = len(words)
        else:
            current_chunk.append(sentence)
            current_word_count += len(words)

    if current_chunk:
        chunks.append('. '.join(current_chunk))

    return chunks
