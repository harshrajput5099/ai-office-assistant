# AI Office Assistant
> Fully Offline AI-Powered Productivity App

![AI Offline First](https://img.shields.io/badge/AI-Offline%20First-brightgreen?style=for-the-badge)
![Platform Android](https://img.shields.io/badge/Platform-Android-blue?style=for-the-badge)
![LLM Mistral 7B](https://img.shields.io/badge/LLM-Mistral%207B-black?style=for-the-badge)
![Speech Whisper](https://img.shields.io/badge/Speech-Whisper-yellow?style=for-the-badge)

---

## Overview

A powerful offline AI assistant built for document summarization, meeting transcription, and professional email generation — running entirely on-device with no cloud dependency, no API costs, and no data leakage.

---

## Features

| Feature | Technology | Status |
|---|---|---|
| PDF summarization | T5-small / Mistral | ✅ |
| Meeting transcription | Whisper + FFmpeg | ✅ |
| Email generation | Mistral (Ollama) | ✅ |
| AI pipeline | Whisper → T5 → Mistral | ✅ |
| Mobile app | Flutter | ✅ |
| Authentication | JWT + SQLite | ✅ |
| History tracking | SQLite | ✅ |
| User settings | Profile management | ✅ |
| Export | TXT / PDF / DOCX | ✅ |
| Offline mode | Local models | ✅ |

---

## AI Pipeline

```
Audio input / Text input
        ↓
Whisper (transcription)
        ↓
T5 / Mistral (summary)
        ↓
Mistral (email generation)
        ↓
Final email output
```

### Endpoint

```
POST /api/pipeline/run
```

**Voice input**
```json
{
  "input_type": "voice",
  "audio_file": "<file>",
  "email_tone": "formal"
}
```

**Text input**
```json
{
  "input_type": "text",
  "text": "We discussed the Q3 budget...",
  "email_tone": "semiformal"
}
```

**Response**
```json
{
  "transcript": "...",
  "summary": "...",
  "email": "Dear Team..."
}
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | FastAPI + Python 3.11 |
| AI models | T5-small, Mistral 7B |
| Speech | faster-whisper |
| PDF | pdfplumber, PyMuPDF |
| Database | SQLite |
| Server | Uvicorn |

---

## Quick Start

### Prerequisites

- Python 3.11
- Flutter SDK
- Ollama
- NVIDIA GPU (optional)

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/ai-office-assistant.git
cd ai-office-assistant
```

### 2. Backend setup

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

API docs available at `http://localhost:8000/docs`

### 3. Flutter setup

```bash
cd frontend/ai_office_app
flutter pub get
flutter run
```

Update the base URL in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://YOUR_IP:8000/api';
```

### 4. Ollama setup

```bash
ollama pull mistral
ollama run mistral
```

---

## API Reference

| Module | Endpoint |
|---|---|
| Summarization | `POST /api/summarize-pdf` · `POST /api/summarize-document` |
| Meeting | `POST /api/transcribe-meeting` |
| Email | `POST /api/generate-email` |
| Pipeline | `POST /api/pipeline/run` |
| Export | `POST /api/export/pdf` · `POST /api/export/word` |
| Auth | `POST /api/register` · `POST /api/login` |
| History | `GET /api/history` · `POST /api/history` |
| Settings | `GET /api/settings` · `POST /api/settings` |

---

## Model Comparison

| Model | Speed | Quality | Best for |
|---|---|---|---|
| T5-small | Fast | Good | Quick summaries |
| Mistral 7B | Slower | Excellent | Emails & deep analysis |

---

## Project Structure

```
ai_office_assistant/
├── backend/
│   ├── routers/
│   ├── models/
│   ├── utils/
│   └── main.py
└── frontend/
    └── ai_office_app/
```

---

## Roadmap

- [x] PDF summarization
- [x] Meeting transcription
- [x] Email generation
- [x] Full AI pipeline
- [x] Auth + history
- [x] Dark mode UI
- [x] Multi-language support
- [x] Analytics dashboard
- [x] Model optimization

---

## Author

**Harsh Tomar** — Capstone project combining AI, mobile development, and offline systems.

---

*If this project helped you, consider starring the repo or opening a pull request.*
