from rouge_score import rouge_scorer
from bert_score import score

def check_accuracy(original_text, generated_summary):
    scorer = rouge_scorer.RougeScorer(
        ['rouge1', 'rouge2', 'rougeL'], 
        use_stemmer=True
    )
    scores = scorer.score(original_text, generated_summary)
    
    print("===== ACCURACY RESULTS =====")
    print(f"ROUGE-1: {scores['rouge1'].fmeasure:.2%}")
    print(f"ROUGE-2: {scores['rouge2'].fmeasure:.2%}")
    print(f"ROUGE-L: {scores['rougeL'].fmeasure:.2%}")
    print("============================")
    return scores

original = """paste your original PDF text here"""
summary = """paste the summary your API returned here"""

check_accuracy(original, summary)

def check_bert_accuracy(original, summary):
    P, R, F1 = score(
        [summary], 
        [original], 
        lang='en', 
        verbose=False
    )
    print(f"BERTScore F1: {F1.mean():.2%}")

check_bert_accuracy(original, summary)