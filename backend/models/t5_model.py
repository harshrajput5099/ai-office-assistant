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

def summarize_chunk(text: str) -> str:
    prompt = f'summarize: {text}'
    inputs = tokenizer(prompt, return_tensors='pt',
                       max_length=512, truncation=True).to(device)
    outputs = model.generate(inputs.input_ids,
                             max_new_tokens=150,
                             min_length=30,
                             num_beams=4,
                             early_stopping=True)
    return tokenizer.decode(outputs[0], skip_special_tokens=True)