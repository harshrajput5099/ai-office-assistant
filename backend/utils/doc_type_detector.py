def detect_document_type(text: str) -> str:
    '''
    Detects document type from text content.
    Returns: journal article, conference paper,
             textbook chapter, or document
    '''
    text_lower = text.lower()[:3000]  # check first 3000 chars only

    # ── Signal words for each type ──────────────────
    journal_signals = [
        'abstract', 'doi:', 'issn', 'vol.', 'no.',
        'journal of', 'biosci', 'nature', 'science',
        'received:', 'accepted:', 'published:',
        'correspondence:', 'keywords:', 'j. ',
    ]
    conference_signals = [
        'aaai', 'neurips', 'nips', 'icml', 'cvpr',
        'acl', 'emnlp', 'iclr', 'sigkdd', 'icassp',
        'proceedings of', 'conference on', 'workshop on',
        'association for the advancement',
    ]
    textbook_signals = [
        'chapter ', 'exercise ', 'definition ',
        'theorem ', 'proof:', 'figure ', 'table ',
        'learning objectives', 'summary questions',
    ]

    # ── Score each type ─────────────────────────────
    scores = {
        'journal article':   sum(1 for s in journal_signals    if s in text_lower),
        'conference paper':  sum(1 for s in conference_signals  if s in text_lower),
        'textbook chapter':  sum(1 for s in textbook_signals    if s in text_lower),
    }

    best_type = max(scores, key=scores.get)

    # Only assign a type if we found at least 2 signals
    if scores[best_type] < 2:
        return 'document'
    return best_type
