# 🤖 AI Office Assistant

> A fully **offline** AI-powered mobile app that summarizes PDFs, transcribes meetings, and generates professional emails — all running on your local machine.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Ollama-Mistral_7B-black?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Whisper-faster--whisper-yellow?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Offline-✅ No Cloud-green?style=for-the-badge" />
</p>

---

## 📱 Features at a Glance

| Feature | Technology | Status |
|---|---|---|
| 📄 PDF Summarization | T5-small / Mistral 7B | ✅ Working |
| 🎙️ Meeting Transcription | faster-whisper + FFmpeg | ✅ Working |
| ✉️ Email Generation | Mistral 7B via Ollama | ✅ Working |
| 🔁 AI Pipeline (Voice/Text → Summary → Email) | Whisper + T5 + Mistral | ✅ Working |
| 📲 Flutter Mobile UI | Flutter + Dart (Android) | ✅ Working |
| 🔐 Auth System | Register / Login / Password Reset | ✅ Working |
| 🕓 History Tracking | Per-user request history | ✅ Working |
| ⚙️ User Settings | Profile + password management | ✅ Working |
| 🔒 Fully Offline | All models run locally | ✅ Working |
| 📤 Export Outputs | `.txt`, `.pdf`, `.docx` | ✅ Working |

---

## 🔁 AI Pipeline — Voice / Text → Summary → Email

One of the most powerful features of this project is the **end-to-end AI pipeline**, accessible via a single API call.

### What it does

```
🎤 Voice Input (audio file)        📝 Plain Text Input
         │                                  │
         ▼                                  ▼
  [Whisper Transcription]           (skip transcription)
         │                                  │
         └──────────────┬───────────────────┘
                        ▼
             [T5 / Mistral Summarization]
                        │
                        ▼
             [Mistral Email Generation]
                        │
                        ▼
             📧 Final Email Output
```

### How to use it

**Endpoint:** `POST /api/pipeline/run`

**Input (voice):**
```json
{
  "input_type": "voice",
  "audio_file": "<base64 or file upload>",
  "email_tone": "formal"
}
```

**Input (plain text):**
```json
{
  "input_type": "text",
  "text": "We discussed the Q3 budget and agreed on a 15% cut...",
  "email_tone": "semiformal"
}
```

**Response:**
```json
{
  "transcript": "We discussed the Q3 budget...",
  "summary": "Q3 budget reduced by 15%...",
  "email": "Dear Team, Following our recent discussion..."
}
```

> **Supported tones:** `formal` | `semiformal` | `friendly`

This pipeline eliminates the need to call three separate endpoints manually. Give it a raw meeting recording or a block of notes — it returns a polished, ready-to-send email in one shot.

---

## 🖥️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (Dart) — Android |
| **Backend** | Python 3.11 + FastAPI + Uvicorn |
| **PDF Processing** | pdfplumber + PyMuPDF |
| **AI Models** | T5-small, Mistral 7B (Ollama) |
| **Transcription** | faster-whisper + FFmpeg |
| **Database** | SQLite (`app.db`) |
| **Hardware** | NVIDIA RTX 4050 (6GB VRAM), 16GB RAM |

---

## ⚙️ Setup & Installation

### Prerequisites

- Python 3.11
- Flutter SDK
- NVIDIA GPU *(optional but recommended)*
- [Ollama](https://ollama.ai) *(required for Mistral-powered features)*

---

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/ai-office-assistant.git
cd ai-office-assistant
```

---

### 2️⃣ Backend Setup

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux
pip install -r requirements.txt
```

---

### 3️⃣ Start the Backend Server

```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Expected output on success:
```
✅ Pipeline: Whisper loaded
T5 model loaded on: cuda
✅ Database initialized — app.db ready
INFO:     Application startup complete.
```

> API docs available at: `http://localhost:8000/docs`

---

### 4️⃣ Flutter Setup

```bash
cd frontend/ai_office_app
flutter clean
flutter pub get
flutter run
```

> ⚙️ In `lib/services/api_service.dart`, set your PC's local IP:
> ```dart
> static const String baseUrl = 'http://YOUR_IP:8000/api';
> ```
> Find your IP with: `ipconfig` (Windows) or `ifconfig` (Linux/macOS)

---

### 5️⃣ Ollama + Mistral Setup

```bash
# Install from https://ollama.ai
ollama pull mistral
ollama run mistral
```

---

## 📡 API Reference — v1.0.0 (OAS 3.1)

### 📄 Summarization
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/summarize-pdf` | Summarize a PDF file |
| `POST` | `/api/summarize-document` | Summarize a plain text document |

### 🎙️ Meeting
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/transcribe-meeting` | Transcribe an audio file (Whisper) |

### ✉️ Email
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/generate-email` | Generate a professional email |

### 🔁 Pipeline
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/pipeline/run` | Full pipeline: Voice/Text → Transcribe → Summarize → Email |

### 📤 Export
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/export/word` | Export output as `.docx` |
| `POST` | `/api/export/pdf` | Export output as `.pdf` |

### 🔐 Auth
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/register` | Register a new user |
| `POST` | `/api/login` | Login |
| `POST` | `/api/forgot-password` | Forgot password |

### 🕓 History
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/history` | Get request history |
| `POST` | `/api/history` | Add history entry |
| `DELETE` | `/api/history/{item_id}` | Delete a history item |

### ⚙️ Settings
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/settings` | Get user settings |
| `POST` | `/api/settings` | Update settings |
| `POST` | `/api/settings/change-password` | Change password |
| `DELETE` | `/api/settings/account` | Delete account |

### 🩺 Health
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Health Check |
| `GET` | `/health` | Health |

---

## 📊 Model Comparison

| Model | Speed | Quality | Best For |
|---|---|---|---|
| T5-small | ⚡ Fast (2–5s) | Good | Quick summaries |
| Mistral 7B | 🐢 Slower (30–60s) | Excellent | Detailed analysis, emails & pipeline |

---

## 📁 Project Structure

```
ai_office_assistant/
├── backend/
│   ├── main.py                    # FastAPI entry point
│   ├── requirements.txt           # Python dependencies
│   ├── app.db                     # SQLite database (auto-created)
│   ├── routers/
│   │   ├── summarize.py           # PDF & document summarization
│   │   ├── meeting.py             # Meeting transcription
│   │   ├── email_gen.py           # Email generation
│   │   ├── pipeline.py            # Full AI pipeline
│   │   ├── export.py              # Word & PDF export
│   │   ├── auth.py                # Register / Login / Auth
│   │   ├── history.py             # History tracking
│   │   └── settings.py            # User settings
│   ├── prompt/
│   │   ├── email_formal.py
│   │   ├── email_friendly.py
│   │   ├── email_semiformal.py
│   │   ├── meeting_notes.py
│   │   ├── summarize_academic.py
│   │   └── summarise_chunk.py
│   ├── models/
│   │   └── t5_model.py            # T5 model loader
│   └── utils/
│       ├── pdf_extractor.py       # PDF text extraction
│       ├── text_cleaner.py        # Text preprocessing
│       └── chunker.py             # Text chunking
└── frontend/
    └── ai_office_app/
        └── lib/
            ├── main.dart
            ├── screens/
            │   ├── home_screen.dart
            │   ├── pdf_screen.dart
            │   ├── meeting_screen.dart
            │   └── email_screen.dart
            └── services/
                ├── api_service.dart
                └── export_service.dart
```

---

## 🏗️ Build Progress

- [x] **Phase 0** — Environment setup
- [x] **Phase 1** — PDF summarization + Flutter UI
- [x] **Phase 2** — Export Summarization (`.txt`, `.pdf`, `.docx`)
- [x] **Phase 3** — Meeting transcription (Whisper)
- [x] **Phase 4** — Email generation & polish
- [x] **Phase 5** — Auth, History, Settings & Pipeline automation
- [x] **Phase 6** — Deployment

---

## 👨‍💻 Author

**Harsh Tomar**  
Built as a capstone project demonstrating fully offline AI integration with mobile applications — combining local LLMs, speech recognition, and document processing into a single Flutter app.

---

> ⭐ If you found this project useful, consider giving it a star!
