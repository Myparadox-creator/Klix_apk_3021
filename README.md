# KLIX - AI Coding Assistant

Klix is a powerful AI coding assistant with a Flutter frontend and a FastAPI backend, designed to provide personalized, memory-augmented coding support.

## Project Structure

- **Frontend**: A modern, high-performance Flutter web application with a sleek "tech" aesthetic.
- **Backend**: A FastAPI server (`New_30_T-Klix-main/`) that interfaces with local models (Ollama) and cloud APIs (Gemini).
- **Memory Layer**: Persistent memory using Mem0 and Qdrant to remember user preferences across sessions.

## Technical Stack

- **Frontend**: Flutter (3.x), Material 3, Custom animations.
- **Backend**: Python 3.x, FastAPI, Uvicorn.
- **AI Models**: Ollama (qwen2.5-coder), Gemini (optional).
- **Database**: Qdrant (for vector embeddings).

## Getting Started

### 1. Backend Setup
```bash
cd New_30_T-Klix-main
pip install -r requirements.txt
# Configure your .env file
python -m uvicorn backend_api:app --reload
```

### 2. Frontend Setup
```bash
# To run in web
flutter run -d chrome
```

## Features

- [x] Dynamic backend URL detection (Platform-aware)
- [x] Sleek Animated UI
- [x] Real-time AI Chat responses
- [ ] Memory Management (Work in progress)
