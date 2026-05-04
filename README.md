🤖 AI Office Assistant
🚀 Fully Offline AI-Powered Productivity App
<p align="center"> <img src="https://img.shields.io/badge/AI-Offline%20First-brightgreen?style=for-the-badge" /> <img src="https://img.shields.io/badge/Platform-Android-blue?style=for-the-badge" /> <img src="https://img.shields.io/badge/LLM-Mistral%207B-black?style=for-the-badge" /> <img src="https://img.shields.io/badge/Speech-Whisper-yellow?style=for-the-badge" /> </p>
🌟 Overview

A powerful offline AI assistant that can:

📄 Summarize PDFs & documents
🎙️ Transcribe meetings
✉️ Generate professional emails

⚡ Runs completely locally — no cloud, no API cost, no data leakage.

🎯 Key Highlights
🔒 100% Offline AI
⚡ End-to-End Automation Pipeline
📱 Mobile-first Flutter UI
🧠 Local LLM + Speech + NLP integration
📊 Features
Feature	Technology	Status
📄 PDF Summarization	T5-small / Mistral	✅
🎙️ Meeting Transcription	Whisper + FFmpeg	✅
✉️ Email Generation	Mistral (Ollama)	✅
🔁 AI Pipeline	Whisper → T5 → Mistral	✅
📲 Mobile App	Flutter	✅
🔐 Authentication	JWT + SQLite	✅
🕓 History Tracking	SQLite	✅
⚙️ User Settings	Profile Management	✅
📤 Export	TXT / PDF / DOCX	✅
🔒 Offline Mode	Local Models	✅
🔁 AI Pipeline
🎤 Audio Input / 📝 Text Input
            │
            ▼
   🧠 Whisper (Transcription)
            │
            ▼
   📄 T5 / Mistral (Summary)
            │
            ▼
   ✉️ Mistral (Email Generation)
            │
            ▼
     📧 Final Email Output
📡 Endpoint
POST /api/pipeline/run
📥 Request Examples
Voice Input
{
  "input_type": "voice",
  "audio_file": "<file>",
  "email_tone": "formal"
}
Text Input
{
  "input_type": "text",
  "text": "We discussed the Q3 budget...",
  "email_tone": "semiformal"
}
📤 Response
{
  "transcript": "...",
  "summary": "...",
  "email": "Dear Team..."
}
🧠 Tech Stack
Layer	Technology
📱 Frontend	Flutter (Dart)
⚙️ Backend	FastAPI + Python 3.11
🧠 AI Models	T5-small, Mistral 7B
🎙️ Speech	faster-whisper
📄 PDF	pdfplumber, PyMuPDF
💾 Database	SQLite
⚡ Server	Uvicorn
⚙️ Installation
🔧 Prerequisites
Python 3.11
Flutter SDK
Ollama
(Optional) NVIDIA GPU
📥 Clone Repository
git clone https://github.com/YOUR_USERNAME/ai-office-assistant.git
cd ai-office-assistant
⚙️ Backend Setup
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
▶️ Run Backend
uvicorn main:app --reload

API Docs:

http://localhost:8000/docs
📱 Flutter Setup
cd frontend/ai_office_app
flutter pub get
flutter run

Update API URL in:

lib/services/api_service.dart
static const String baseUrl = 'http://YOUR_IP:8000/api';
🤖 Ollama Setup
ollama pull mistral
ollama run mistral
📡 API Modules
📄 Summarization
POST /api/summarize-pdf
POST /api/summarize-document
🎙️ Meeting
POST /api/transcribe-meeting
✉️ Email
POST /api/generate-email
🔁 Pipeline
POST /api/pipeline/run
📤 Export
POST /api/export/pdf
POST /api/export/word
🔐 Auth
POST /api/register
POST /api/login
🕓 History
GET /api/history
POST /api/history
⚙️ Settings
GET /api/settings
POST /api/settings
📊 Model Comparison
Model	Speed	Quality	Use Case
T5-small	Fast	Good	Quick summaries
Mistral 7B	Slower	Excellent	Emails & deep analysis
📁 Project Structure
ai_office_assistant/
├── backend/
│   ├── routers/
│   ├── models/
│   ├── utils/
│   └── main.py
└── frontend/
    └── ai_office_app/
🏗️ Development Progress
✅ Setup
✅ Summarization
✅ Transcription
✅ Email Generation
✅ Pipeline
✅ Auth + History
✅ Deployment
🔮 Future Improvements
🌙 Dark Mode UI
🌍 Multi-language Support
📊 Analytics Dashboard
⚡ Model Optimization
👨‍💻 Author

Harsh Tomar

Capstone project combining AI + Mobile Development + Offline Systems

⭐ Support

If you like this project:

⭐ Star the repo
🍴 Fork it
🤝 Contribute
