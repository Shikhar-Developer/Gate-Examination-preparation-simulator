from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.all_models import User, ExaminationAttempt, ExaminationEvent, AttemptStatus, Test
from app.core.dependencies import get_current_admin

router = APIRouter(prefix="/admin", tags=["Administrator"])

@router.get("/students")
def get_all_students(admin: User = Depends(get_current_admin), db: Session = Depends(get_db)):
    students = db.query(User).filter(User.role == "student").all()
    res = []
    for s in students:
        attempts_count = db.query(ExaminationAttempt).filter(ExaminationAttempt.user_id == s.id).count()
        res.append({
            "id": s.id,
            "username": s.username,
            "full_name": s.full_name,
            "email": s.email,
            "is_active": s.is_active,
            "total_attempts": attempts_count
        })
    return res

@router.get("/live-monitoring")
def live_monitoring(admin: User = Depends(get_current_admin), db: Session = Depends(get_db)):
    active_attempts = db.query(ExaminationAttempt).filter(
        ExaminationAttempt.status == AttemptStatus.IN_PROGRESS
    ).all()
    result = []
    for a in active_attempts:
        user = db.query(User).filter(User.id == a.user_id).first()
        test = db.query(Test).filter(Test.id == a.test_id).first()
        events = db.query(ExaminationEvent).filter(ExaminationEvent.attempt_id == a.id).order_by(ExaminationEvent.timestamp.desc()).limit(3).all()
        result.append({
            "attempt_id": a.id,
            "student_name": user.full_name if user else "Unknown",
            "test_title": test.title if test else "Unknown",
            "time_remaining": a.server_time_remaining,
            "recent_events": [f"{e.event_type}: {e.details or ''}" for e in events]
        })
    return result

@router.get("/comparative-analytics")
def comparative_analytics(admin: User = Depends(get_current_admin), db: Session = Depends(get_db)):
    students = db.query(User).filter(User.role == "student").all()
    metrics = []
    for s in students:
        attempts = db.query(ExaminationAttempt).filter(
            ExaminationAttempt.user_id == s.id,
            ExaminationAttempt.status == AttemptStatus.COMPLETED
        ).all()
        if attempts:
            avg_score = round(sum(a.score for a in attempts) / len(attempts), 2)
            avg_acc = round(sum(a.accuracy for a in attempts) / len(attempts), 2)
            total_tukka = sum(a.tukka_count for a in attempts)
        else:
            avg_score = 0.0
            avg_acc = 0.0
            total_tukka = 0
        metrics.append({
            "student_id": s.id,
            "student_name": s.full_name,
            "completed_tests": len(attempts),
            "average_score": avg_score,
            "average_accuracy": avg_acc,
            "total_guesses": total_tukka
        })
    return metrics
