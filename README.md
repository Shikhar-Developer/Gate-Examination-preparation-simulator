# GATE Examination & Performance Management System

A multi-user, cross-computer GATE Examination desktop and server platform built with **FastAPI**, **PostgreSQL**, and **Flutter Desktop (Windows/Linux/macOS)**.

## Key Features
- **GATE-Compliant Test Interface**: MCQ, MSQ, NAT questions with exact palette states.
- **TUKKA (Guessing Analytics)**: Violet Tukka button to track and measure guessing accuracy independently.
- **Solution Mode & Question Lock**: View solutions with YouTube video integrations, triggering a 5-minute server-persisted question lock.
- **Cross-Computer Central Synchronization**: Server-authoritative timer, real-time live monitoring for administrators, and persistent student attempts.
- **Administrator Command Dashboard**: Live test surveillance, comparative student analytics, and consistency metrics.

---

## 1. Quick Start with Docker (Backend & Database)

Run the backend and PostgreSQL database with Docker Compose:

```bash
docker compose up --build -d
```

The FastAPI REST backend will start at `http://localhost:8000`.
- API Docs: `http://localhost:8000/docs`
- Default Users pre-seeded:
  - **Admin**: username `admin`, password `admin123`
  - **Student 1**: username `student1`, password `student123`
  - **Student 2**: username `student2`, password `student123`

---

## 2. Running Backend Manually (Without Docker)

```bash
cd backend
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

pip install -r requirements.txt
python -m app.main
```

---

## 3. Running the Flutter Desktop Application

Ensure Flutter is installed on Windows:

```bash
cd frontend
flutter pub get
flutter run -d windows
```

To connect from other computers on your LAN, update `frontend/lib/core/constants/api_constants.dart` with the host machine's IP address.
