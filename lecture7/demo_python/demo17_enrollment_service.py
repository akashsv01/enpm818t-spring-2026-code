"""
Demo 17: EnrollmentService with Repository Pattern
Covers: connection pooling, FOR UPDATE, service layer, error handling
"""

import os

import psycopg
import psycopg_pool
from dotenv import load_dotenv
from psycopg.errors import ForeignKeyViolation, UniqueViolation
from psycopg.rows import dict_row

load_dotenv()


# --- config/database.py ---

class DatabaseConfig:
    _pool = None

    @classmethod
    def _conninfo(cls):
        return (
            f"host={os.getenv('DB_HOST', 'localhost')} "
            f"port={os.getenv('DB_PORT', '5432')} "
            f"dbname={os.getenv('DB_NAME')} "
            f"user={os.getenv('DB_USER')} "
            f"password={os.getenv('DB_PASSWORD')}"
        )

    @classmethod
    def initialize(cls):
        cls._pool = psycopg_pool.ConnectionPool(
            conninfo=cls._conninfo(),
            min_size=2,
            max_size=10,
            open=True,
        )

    @classmethod
    def get_connection(cls):
        if cls._pool is None:
            cls.initialize()
        return cls._pool.connection()

    @classmethod
    def close(cls):
        if cls._pool is not None:
            cls._pool.close()
            cls._pool = None


# --- repositories/enrollment_repo.py ---

class EnrollmentRepository:

    def find_by_student(self, person_id):
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT * FROM enrollment "
                    "WHERE student_person_id = %s",
                    (person_id,),
                )
                return cur.fetchall()

    def get_section_capacity(self, conn, course_id, section_no):
        """Must be called inside an existing transaction with FOR UPDATE."""
        with conn.cursor() as cur:
            cur.execute(
                "SELECT capacity FROM course_section "
                "WHERE course_id = %s AND section_no = %s "
                "FOR UPDATE",
                (course_id, section_no),
            )
            return cur.fetchone()


# --- services/enrollment_service.py ---

class EnrollmentService:

    def __init__(self):
        self.repo = EnrollmentRepository()

    def enroll_student(self, person_id, course_id, section_no):
        with DatabaseConfig.get_connection() as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    # Lock the row and read capacity
                    cur.execute(
                        "SELECT capacity FROM course_section "
                        "WHERE course_id = %s AND section_no = %s "
                        "FOR UPDATE",
                        (course_id, section_no),
                    )
                    row = cur.fetchone()
                    if row is None:
                        raise ValueError("Section not found")
                    if row[0] <= 0:
                        raise ValueError("Section is full")

                    # Decrement capacity
                    cur.execute(
                        "UPDATE course_section "
                        "SET capacity = capacity - 1 "
                        "WHERE course_id = %s AND section_no = %s",
                        (course_id, section_no),
                    )

                    # Insert enrollment
                    try:
                        cur.execute(
                            "INSERT INTO enrollment "
                            "(student_person_id, course_id, section_no) "
                            "VALUES (%s, %s, %s)",
                            (person_id, course_id, section_no),
                        )
                    except UniqueViolation:
                        raise ValueError("Already enrolled")
                    except ForeignKeyViolation:
                        raise ValueError("Student or section not found")


# --- Demo script ---

def main():
    DatabaseConfig.initialize()
    svc = EnrollmentService()

    # Set capacity to 2 for this demo
    with DatabaseConfig.get_connection() as conn:
        with conn.transaction():
            conn.execute(
                "UPDATE course_section SET capacity = 2 "
                "WHERE course_id = 'ENPM818T' AND section_no = '0101'"
            )

    # Clean up any leftover enrollment rows for students 2, 4
    with DatabaseConfig.get_connection() as conn:
        with conn.transaction():
            conn.execute(
                "DELETE FROM enrollment "
                "WHERE student_person_id IN (2, 4) "
                "AND course_id = 'ENPM818T' AND section_no = '0101'"
            )

    # Enroll student 2 (capacity 2 -> 1)
    print("Enrolling student 2...")
    svc.enroll_student(2, "ENPM818T", "0101")
    print("  OK")

    # Enroll student 4 (capacity 1 -> 0)
    print("Enrolling student 4...")
    svc.enroll_student(4, "ENPM818T", "0101")
    print("  OK")

    # Attempt to enroll student 5 (capacity 0 -> should fail)
    print("Enrolling student 5 (should fail -- section full)...")
    try:
        svc.enroll_student(5, "ENPM818T", "0101")
    except ValueError as e:
        print(f"  Caught: {e}")

    # Verify capacity in Python
    with DatabaseConfig.get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT capacity FROM course_section "
                "WHERE course_id = 'ENPM818T' AND section_no = '0101'"
            )
            print(f"\nFinal capacity: {cur.fetchone()[0]}")

    # Cleanup: restore capacity and remove test enrollments
    with DatabaseConfig.get_connection() as conn:
        with conn.transaction():
            conn.execute(
                "DELETE FROM enrollment "
                "WHERE student_person_id IN (2, 4) "
                "AND course_id = 'ENPM818T' AND section_no = '0101'"
            )
            conn.execute(
                "UPDATE course_section SET capacity = 30 "
                "WHERE course_id = 'ENPM818T' AND section_no = '0101'"
            )
    print("Cleanup done.")

    DatabaseConfig.close()


if __name__ == "__main__":
    main()
