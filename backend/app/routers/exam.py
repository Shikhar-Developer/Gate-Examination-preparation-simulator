from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.all_models import (
    User, Test, TestQuestion, Question, ExaminationAttempt,
    StudentResponse, ExaminationEvent, SolutionView, Bookmark, AttemptStatus, QuestionType
)
from app.schemas.all_schemas import ResponseSave, ExaminationEventCreate, SolutionViewOut
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/exam", tags=["Examination"])

@router.get("/tests")
def get_available_tests(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    tests = db.query(Test).filter(Test.is_active == True).all()
    res = []
    for t in tests:
        q_count = db.query(TestQuestion).filter(TestQuestion.test_id == t.id).count()
        res.append({
            "id": t.id,
            "title": t.title,
            "chapter_id": t.chapter_id,
            "duration_minutes": t.duration_minutes,
            "total_marks": t.total_marks,
            "question_count": q_count
        })
    return res

@router.post("/start/{test_id}")
def start_exam(test_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    test = db.query(Test).filter(Test.id == test_id).first()
    if not test:
        raise HTTPException(status_code=404, detail="Test not found")

    attempt = db.query(ExaminationAttempt).filter(
        ExaminationAttempt.user_id == current_user.id,
        ExaminationAttempt.test_id == test_id,
        ExaminationAttempt.status == AttemptStatus.IN_PROGRESS
    ).first()

    if not attempt:
        attempt = ExaminationAttempt(
            user_id=current_user.id,
            test_id=test_id,
            status=AttemptStatus.IN_PROGRESS,
            server_time_remaining=test.duration_minutes * 60
        )
        db.add(attempt)
        db.commit()
        db.refresh(attempt)

    tq_list = db.query(TestQuestion).filter(TestQuestion.test_id == test_id).order_by(TestQuestion.order_index).all()
    questions = []
    for tq in tq_list:
        q = db.query(Question).filter(Question.id == tq.question_id).first()
        if q:
            questions.append({
                "id": q.id,
                "order": tq.order_index,
                "statement": q.question_statement,
                "type": q.question_type.value,
                "marks": q.marks,
                "negative_marks": q.negative_marks,
                "options": q.options,
                "exam_year": q.exam_year
            })

    existing_responses = db.query(StudentResponse).filter(StudentResponse.attempt_id == attempt.id).all()
    saved_answers = {
        r.question_id: {
            "selected_answer": r.selected_answer,
            "is_tukka": r.is_tukka,
            "is_marked_for_review": r.is_marked_for_review,
            "is_answered": r.is_answered,
            "time_spent_seconds": r.time_spent_seconds
        } for r in existing_responses
    }

    return {
        "attempt_id": attempt.id,
        "test_title": test.title,
        "server_time_remaining": attempt.server_time_remaining,
        "questions": questions,
        "saved_responses": saved_answers
    }

@router.post("/save-response/{attempt_id}")
def save_response(
    attempt_id: int,
    payload: ResponseSave,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    attempt = db.query(ExaminationAttempt).filter(
        ExaminationAttempt.id == attempt_id,
        ExaminationAttempt.user_id == current_user.id
    ).first()
    if not attempt or attempt.status != AttemptStatus.IN_PROGRESS:
        raise HTTPException(status_code=400, detail="Invalid attempt or already completed")

    resp = db.query(StudentResponse).filter(
        StudentResponse.attempt_id == attempt_id,
        StudentResponse.question_id == payload.question_id
    ).first()

    if not resp:
        resp = StudentResponse(attempt_id=attempt_id, question_id=payload.question_id)
        db.add(resp)

    resp.selected_answer = payload.selected_answer
    resp.is_tukka = payload.is_tukka
    resp.is_marked_for_review = payload.is_marked_for_review
    resp.is_answered = payload.is_answered
    resp.time_spent_seconds += payload.time_spent_seconds
    db.commit()
    return {"status": "saved"}

@router.post("/event/{attempt_id}")
def log_event(
    attempt_id: int,
    event: ExaminationEventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ev = ExaminationEvent(
        attempt_id=attempt_id,
        event_type=event.event_type,
        details=event.details
    )
    db.add(ev)
    db.commit()
    return {"status": "event_logged"}

@router.post("/solution-view/{question_id}", response_model=SolutionViewOut)
def view_solution(
    question_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    q = db.query(Question).filter(Question.id == question_id).first()
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")

    locked_until = datetime.utcnow() + timedelta(minutes=5)
    sol_view = SolutionView(
        user_id=current_user.id,
        question_id=question_id,
        locked_until=locked_until
    )
    db.add(sol_view)
    db.commit()

    return SolutionViewOut(
        question_id=q.id,
        correct_answer=q.correct_answer,
        explanation=q.explanation,
        youtube_url=q.youtube_url,
        locked_until=locked_until
    )

@router.post("/submit/{attempt_id}")
def submit_exam(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    attempt = db.query(ExaminationAttempt).filter(
        ExaminationAttempt.id == attempt_id,
        ExaminationAttempt.user_id == current_user.id
    ).first()
    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found")

    responses = db.query(StudentResponse).filter(StudentResponse.attempt_id == attempt_id).all()
    total_score = 0.0
    correct_count = 0
    total_answered = 0
    tukka_total = 0
    tukka_correct = 0

    for r in responses:
        q = db.query(Question).filter(Question.id == r.question_id).first()
        if not q or not r.is_answered or not r.selected_answer:
            r.is_correct = False
            r.marks_awarded = 0.0
            continue

        total_answered += 1
        if r.is_tukka:
            tukka_total += 1

        is_right = False
        if q.question_type == QuestionType.NAT:
            try:
                # NAT can be single value or range "min-max"
                if "-" in q.correct_answer:
                    low, high = map(float, q.correct_answer.split("-"))
                    val = float(r.selected_answer.strip())
                    is_right = (low <= val <= high)
                else:
                    is_right = abs(float(r.selected_answer.strip()) - float(q.correct_answer.strip())) < 1e-4
            except:
                is_right = False
        elif q.question_type == QuestionType.MSQ:
            ans_set = set([x.strip().upper() for x in q.correct_answer.split(",") if x.strip()])
            sel_set = set([x.strip().upper() for x in r.selected_answer.split(",") if x.strip()])
            is_right = (ans_set == sel_set)
        else: # MCQ
            is_right = (r.selected_answer.strip().upper() == q.correct_answer.strip().upper())

        r.is_correct = is_right
        if is_right:
            correct_count += 1
            r.marks_awarded = q.marks
            total_score += q.marks
            if r.is_tukka:
                tukka_correct += 1
        else:
            if q.question_type == QuestionType.MCQ:
                r.marks_awarded = -abs(q.negative_marks)
                total_score -= abs(q.negative_marks)
            else:
                r.marks_awarded = 0.0

    attempt.status = AttemptStatus.COMPLETED
    attempt.end_time = datetime.utcnow()
    attempt.score = round(total_score, 2)
    attempt.accuracy = round((correct_count / total_answered * 100), 2) if total_answered > 0 else 0.0
    attempt.tukka_count = tukka_total
    attempt.tukka_accuracy = round((tukka_correct / tukka_total * 100), 2) if tukka_total > 0 else 0.0

    db.commit()
    return {
        "status": "completed",
        "score": attempt.score,
        "accuracy": attempt.accuracy,
        "correct_count": correct_count,
        "total_answered": total_answered,
        "tukka_total": tukka_total,
        "tukka_accuracy": attempt.tukka_accuracy
    }
