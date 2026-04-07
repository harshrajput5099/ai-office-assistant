# 🤖 AI Office Assistant

A fully offline AI-powered mobile app that summarizes PDFs, transcribes meetings, and generates professional emails — all running on your local machine.

---

## 📱 Screenshots

| Home Screen | PDF Summarizer | Meeting Notes | Email Generator |
|---|---|---|---|
| ✅ Working  | ✅ Working | Coming soon | Coming soon |

---

## 🚀 Features

| Feature | Technology | Status |
|---|---|---|
| PDF Summarization | T5-small / Mistral 7B | ✅ Working |
| Meeting Transcription | Whisper (faster-whisper) | 🔲 Phase 2 |
| Email Generation | Mistral 7B via Ollama | 🔲 Phase 2 |
| Flutter Mobile UI | Flutter + Dart | ✅ Working |
| Offline Processing | All models run locally | ✅ Working |

---

## 🖥️ Tech Stack

- **Frontend**: Flutter (Dart) — Android
- **Backend**: Python 3.11 + FastAPI + Uvicorn
- **AI Models**: T5-small, Mistral 7B (via Ollama)
- **PDF Processing**: pdfplumber + PyMuPDF
- **Meeting Transcription**: faster-whisper + FFmpeg
- **Hardware**: NVIDIA RTX 4050 (6GB VRAM), 16GB RAM

---

## ⚙️ Setup & Installation

### Prerequisites
- Python 3.11
- Flutter SDK
- NVIDIA GPU (optional but recommended)
- Ollama (for Mistral features)

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/ai-office-assistant.git
cd ai-office-assistant
```

### 2. Backend Setup
```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

### 3. Run the Backend Server
```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Flutter Setup
```bash
cd frontend/ai_office_app
flutter pub get
flutter run
```

### 5. Ollama Setup (for Mistral features)
```bash
# Install from https://ollama.ai
ollama pull mistral
ollama run mistral
```

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Health check |
| POST | `/api/summarize-pdf` | Summarize PDF (T5 or Mistral) |
| POST | `/api/transcribe-meeting` | Transcribe audio (Whisper) |
| POST | `/api/generate-email` | Generate email (Mistral) |

Full API docs at: `http://localhost:8000/docs`

---

## 📁 Project Structure

```
ai_office_assistant/
├── backend/
│   ├── main.py                  # FastAPI entry point
│   ├── requirements.txt         # Python dependencies
│   ├── routers/
│   │   ├── summarize.py         # PDF summarization
│   │   ├── meeting.py           # Meeting transcription
│   │   └── email_gen.py         # Email generation
│   ├── models/
│   │   └── t5_model.py          # T5 model loader
│   └── utils/
│       ├── pdf_extractor.py     # PDF text extraction
│       ├── text_cleaner.py      # Text preprocessing
│       └── chunker.py           # Text chunking
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
                └── api_service.dart
```

---

## 🔧 Configuration

In `frontend/ai_office_app/lib/services/api_service.dart`:
```dart
// Change to your PC's local IP address
static const String baseUrl = 'http://YOUR_IP:8000/api';
```

Find your IP with: `ipconfig` (Windows)

---

## 📊 Model Comparison

| Model | Speed | Quality | Use Case |
|---|---|---|---|
| T5-small | Fast (2-5s) | Good | Quick summaries |
| Mistral 7B | Slower (30-60s) | Excellent | Detailed analysis |

---

## 🏗️ Build Phases

- **Phase 0** ✅ — Environment setup
- **Phase 1** ✅ — PDF summarization + Flutter UI
- **Phase 2** 🔲 — Meeting transcription (Whisper)
- **Phase 3** 🔲 — Email polish + deployment

---

## 👨‍💻 Author

**Harsh Tomar**
Built as a capstone project demonstrating offline AI integration with mobile applications.
