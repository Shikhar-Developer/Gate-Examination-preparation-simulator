import enum
from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Text, Boolean, Float, DateTime, ForeignKey, Enum, JSON
)
from sqlalchemy.orm import relationship
from app.database.session import Base

class UserRole(str, enum.Enum):
    STUDENT = "student"
    ADMIN = "admin"

class QuestionType(str, enum.Enum):
    MCQ = "MCQ"
    MSQ = "MSQ"
    NAT = "NAT"

class AttemptStatus(str, enum.Enum):
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    AUTO_SUBMITTED = "auto_submitted"

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.STUDENT, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    group_memberships = relationship("GroupMember", back_populates="user", cascade="all, delete-orphan")
    attempts = relationship("ExaminationAttempt", back_populates="user")
    bookmarks = relationship("Bookmark", back_populates="user")
    solution_views = relationship("SolutionView", back_populates="user")

class Group(Base):
    __tablename__ = "groups"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    members = relationship("GroupMember", back_populates="group", cascade="all, delete-orphan")
    assignments = relationship("TestAssignment", back_populates="group")

class GroupMember(Base):
    __tablename__ = "group_members"
    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow)

    group = relationship("Group", back_populates="members")
    user = relationship("User", back_populates="group_memberships")

class Subject(Base):
    __tablename__ = "subjects"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), unique=True, nullable=False)
    code = Column(String(50), unique=True, nullable=False)
    
    chapters = relationship("Chapter", back_populates="subject", cascade="all, delete-orphan")

class Chapter(Base):
    __tablename__ = "chapters"
    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    name = Column(String(200), nullable=False)

    subject = relationship("Subject", back_populates="chapters")
    topics = relationship("Topic", back_populates="chapter", cascade="all, delete-orphan")
    tests = relationship("Test", back_populates="chapter")

class Topic(Base):
    __tablename__ = "topics"
    id = Column(Integer, primary_key=True, index=True)
    chapter_id = Column(Integer, ForeignKey("chapters.id"), nullable=False)
    name = Column(String(200), nullable=False)

    chapter = relationship("Chapter", back_populates="topics")
    questions = relationship("Question", back_populates="topic")

class Question(Base):
    __tablename__ = "questions"
    id = Column(Integer, primary_key=True, index=True)
    topic_id = Column(Integer, ForeignKey("topics.id"), nullable=False)
    question_statement = Column(Text, nullable=False)
    question_type = Column(Enum(QuestionType), nullable=False)
    exam_year = Column(Integer, nullable=True)
    marks = Column(Float, default=1.0)
    negative_marks = Column(Float, default=0.33)
    options = Column(JSON, nullable=True)  # List of {"identifier": "A", "text": "..."}
    correct_answer = Column(Text, nullable=False)  # "A" or "A,C" or range "12.5-13.0"
    explanation = Column(Text, nullable=True)
    youtube_url = Column(String(500), nullable=True)
    difficulty = Column(String(50), default="Medium")

    topic = relationship("Topic", back_populates="questions")
    test_links = relationship("TestQuestion", back_populates="question")
    responses = relationship("StudentResponse", back_populates="question")
    bookmarks = relationship("Bookmark", back_populates="question")
    solution_views = relationship("SolutionView", back_populates="question")

class Test(Base):
    __tablename__ = "tests"
    id = Column(Integer, primary_key=True, index=True)
    chapter_id = Column(Integer, ForeignKey("chapters.id"), nullable=False)
    title = Column(String(200), nullable=False)
    duration_minutes = Column(Integer, default=90)
    total_marks = Column(Float, default=30.0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    chapter = relationship("Chapter", back_populates="tests")
    test_questions = relationship("TestQuestion", back_populates="test", cascade="all, delete-orphan")
    assignments = relationship("TestAssignment", back_populates="test")
    attempts = relationship("ExaminationAttempt", back_populates="test")

class TestQuestion(Base):
    __tablename__ = "test_questions"
    id = Column(Integer, primary_key=True, index=True)
    test_id = Column(Integer, ForeignKey("tests.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    order_index = Column(Integer, default=1)

    test = relationship("Test", back_populates="test_questions")
    question = relationship("Question", back_populates="test_links")

class TestAssignment(Base):
    __tablename__ = "test_assignments"
    id = Column(Integer, primary_key=True, index=True)
    test_id = Column(Integer, ForeignKey("tests.id"), nullable=False)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)

    test = relationship("Test", back_populates="assignments")
    group = relationship("Group", back_populates="assignments")

class ExaminationAttempt(Base):
    __tablename__ = "examination_attempts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    test_id = Column(Integer, ForeignKey("tests.id"), nullable=False)
    status = Column(Enum(AttemptStatus), default=AttemptStatus.IN_PROGRESS)
    start_time = Column(DateTime, default=datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    server_time_remaining = Column(Integer, nullable=False)  # in seconds
    score = Column(Float, default=0.0)
    accuracy = Column(Float, default=0.0)
    tukka_accuracy = Column(Float, default=0.0)
    tukka_count = Column(Integer, default=0)

    user = relationship("User", back_populates="attempts")
    test = relationship("Test", back_populates="attempts")
    responses = relationship("StudentResponse", back_populates="attempt", cascade="all, delete-orphan")
    events = relationship("ExaminationEvent", back_populates="attempt", cascade="all, delete-orphan")

class StudentResponse(Base):
    __tablename__ = "student_responses"
    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("examination_attempts.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    selected_answer = Column(Text, nullable=True)
    is_tukka = Column(Boolean, default=False)
    is_marked_for_review = Column(Boolean, default=False)
    is_answered = Column(Boolean, default=False)
    time_spent_seconds = Column(Integer, default=0)
    is_correct = Column(Boolean, nullable=True)
    marks_awarded = Column(Float, default=0.0)

    attempt = relationship("ExaminationAttempt", back_populates="responses")
    question = relationship("Question", back_populates="responses")

class SolutionView(Base):
    __tablename__ = "solution_views"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    viewed_at = Column(DateTime, default=datetime.utcnow)
    locked_until = Column(DateTime, nullable=False)

    user = relationship("User", back_populates="solution_views")
    question = relationship("Question", back_populates="solution_views")

class Bookmark(Base):
    __tablename__ = "bookmarks"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="bookmarks")
    question = relationship("Question", back_populates="bookmarks")

class ExaminationEvent(Base):
    __tablename__ = "examination_events"
    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("examination_attempts.id"), nullable=False)
    event_type = Column(String(100), nullable=False)  # "FOCUS_LOST", "FULLSCREEN_EXIT", "HEARTBEAT"
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    attempt = relationship("ExaminationAttempt", back_populates="events")
