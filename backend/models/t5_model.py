from transformers import T5ForConditionalGeneration, T5Tokenizer
import torch

# Load once at module import — not on every request
print('Loading T5 model... (first time may take 1-2 minutes)')
MODEL_NAME = 't5-small'
tokenizer = T5Tokenizer.from_pretrained(MODEL_NAME)
model = T5ForConditionalGeneration.from_pretrained(MODEL_NAME)

# Use GPU if available
device = 'cuda' if torch.cuda.is_available() else 'cpu'
model = model.to(device)
print(f'T5 model loaded on: {device}')

def summarize_chunk(text: str, doc_type: str = 'document') -> str:
    # Load prompt template from file
    try:
        with open('prompts/summarize_chunk.txt', 'r') as f:
            template = f.read()
        prompt = template.format(doc_type=doc_type, text=text)
    except FileNotFoundError:
        # Fallback if prompt file not found
        prompt = f'summarize this {doc_type} section accurately: {text}'

    inputs = tokenizer(
        prompt,
        return_tensors='pt',
        max_length=512,
        truncation=True
    ).to(device)

    outputs = model.generate(
        inputs.input_ids,
        max_new_tokens=200,      # was 150 — increase for more detail
        min_length=50,           # was 30 — force more content
        num_beams=5,             # was 4 — better quality search
        no_repeat_ngram_size=3,  # NEW — prevents repetition
        length_penalty=1.5,      # NEW — rewards longer outputs
        early_stopping=True
    )
    return tokenizer.decode(outputs[0], skip_special_tokens=True)
