import json
from app.database.session import SessionLocal, engine, Base
from app.models.all_models import (
    User, UserRole, Subject, Chapter, Topic, Question, QuestionType, Test, TestQuestion
)
from app.core.security import get_password_hash

def init_seed_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Check if already seeded
        if db.query(User).filter(User.username == "admin").first():
            print("Database already seeded.")
            return

        print("Seeding initial users...")
        admin = User(
            email="admin@gate.internal",
            username="admin",
            full_name="Exam Administrator",
            hashed_password=get_password_hash("admin123"),
            role=UserRole.ADMIN
        )
        s1 = User(
            email="student1@gate.internal",
            username="student1",
            full_name="Student One",
            hashed_password=get_password_hash("student123"),
            role=UserRole.STUDENT
        )
        s2 = User(
            email="student2@gate.internal",
            username="student2",
            full_name="Student Two",
            hashed_password=get_password_hash("student123"),
            role=UserRole.STUDENT
        )
        db.add_all([admin, s1, s2])
        db.commit()

        print("Seeding GATE Subjects, Chapters, Topics & Questions...")
        dbms = Subject(name="Database Management Systems", code="CS_DBMS")
        os_subj = Subject(name="Operating Systems", code="CS_OS")
        db.add_all([dbms, os_subj])
        db.commit()

        ch1 = Chapter(subject_id=dbms.id, name="Transactions and Concurrency Control")
        ch2 = Chapter(subject_id=os_subj.id, name="CPU Scheduling and Deadlocks")
        db.add_all([ch1, ch2])
        db.commit()

        top1 = Topic(chapter_id=ch1.id, name="Serializability & Two-Phase Locking")
        top2 = Topic(chapter_id=ch2.id, name="Deadlock Detection & Bankers Algorithm")
        db.add_all([top1, top2])
        db.commit()

        # Questions
        q1 = Question(
            topic_id=top1.id,
            question_statement="Which of the following schedules is conflict serializable?\nLet S1: r1(X); r2(X); w1(X); w2(X);",
            question_type=QuestionType.MCQ,
            exam_year=2023,
            marks=1.0,
            negative_marks=0.33,
            options=[
                {"identifier": "A", "text": "Schedule S1 is Conflict Serializable"},
                {"identifier": "B", "text": "Schedule S1 is Not Conflict Serializable"},
                {"identifier": "C", "text": "S1 contains a blind write"},
                {"identifier": "D", "text": "Both A and C"}
            ],
            correct_answer="B",
            explanation="The precedence graph for S1 has edges 1 -> 2 (from r1(X) to w2(X)) and 2 -> 1 (from r2(X) to w1(X)), forming a cycle. Thus not conflict serializable.",
            youtube_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )

        q2 = Question(
            topic_id=top1.id,
            question_statement="Which of the following statements are TRUE regarding Strict 2PL? (Select all that apply)",
            question_type=QuestionType.MSQ,
            exam_year=2022,
            marks=2.0,
            negative_marks=0.0,
            options=[
                {"identifier": "A", "text": "It guarantees conflict serializability"},
                {"identifier": "B", "text": "It guarantees freedom from deadlocks"},
                {"identifier": "C", "text": "It prevents cascading aborts"},
                {"identifier": "D", "text": "All exclusive locks are held until commit/abort"}
            ],
            correct_answer="A,C,D",
            explanation="Strict 2PL prevents cascading aborts and guarantees serializability, but it does NOT prevent deadlocks.",
            youtube_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )

        q3 = Question(
            topic_id=top2.id,
            question_statement="Consider a system with 3 processes sharing 4 instances of a single resource type. What is the maximum resource requirement each process can have while ensuring the system never deadlocks?",
            question_type=QuestionType.NAT,
            exam_year=2021,
            marks=1.0,
            negative_marks=0.0,
            options=[],
            correct_answer="2",
            explanation="For N processes and M resources, condition for deadlock free is sum(max_demands) < N + M. 3*(k) < 3 + 4 => 3k < 7 => k <= 2.",
            youtube_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )

        db.add_all([q1, q2, q3])
        db.commit()

        # Create Standard Test
        test = Test(
            chapter_id=ch1.id,
            title="GATE CSE: DBMS & OS Chapter Benchmark Test 01",
            duration_minutes=90,
            total_marks=30.0
        )
        db.add(test)
        db.commit()

        tq1 = TestQuestion(test_id=test.id, question_id=q1.id, order_index=1)
        tq2 = TestQuestion(test_id=test.id, question_id=q2.id, order_index=2)
        tq3 = TestQuestion(test_id=test.id, question_id=q3.id, order_index=3)
        db.add_all([tq1, tq2, tq3])
        db.commit()

        print("Dataset seeded successfully!")
    finally:
        db.close()

if __name__ == "__main__":
    init_seed_data()
