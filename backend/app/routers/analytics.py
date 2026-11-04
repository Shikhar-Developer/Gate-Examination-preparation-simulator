from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.all_models import User, ExaminationAttempt, AttemptStatus, Test
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])

@router.get("/my-history")
def get_user_history(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    attempts = db.query(ExaminationAttempt).filter(
        ExaminationAttempt.user_id == current_user.id,
        ExaminationAttempt.status == AttemptStatus.COMPLETED
    ).order_by(ExaminationAttempt.end_time.desc()).all()

    res = []
    for a in attempts:
        t = db.query(Test).filter(Test.id == a.test_id).first()
        res.append({
            "attempt_id": a.id,
            "test_title": t.title if t else "Exam",
            "score": a.score,
            "accuracy": a.accuracy,
            "tukka_count": a.tukka_count,
            "tukka_accuracy": a.tukka_accuracy,
            "date": a.end_time.strftime("%Y-%m-%d %H:%M") if a.end_time else ""
        })
    return res
