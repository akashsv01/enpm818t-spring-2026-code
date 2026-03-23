"""
Demo 15: Transactions in Python
Covers: conn.transaction(), automatic COMMIT/ROLLBACK, parameterized queries
"""

import os

import psycopg
from dotenv import load_dotenv

load_dotenv()

conn_str = (
    f"host={os.getenv('DB_HOST', 'localhost')} "
    f"port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('DB_NAME')} "
    f"user={os.getenv('DB_USER')} "
    f"password={os.getenv('DB_PASSWORD')}"
)


def enroll(conn, person_id, course_id, section_no):
    """Enroll a student atomically: decrement capacity + insert enrollment."""
    with conn.transaction():
        conn.execute(
            "UPDATE course_section "
            "SET capacity = capacity - 1 "
            "WHERE course_id = %s "
            "  AND section_no = %s",
            (course_id, section_no),
        )
        conn.execute(
            "INSERT INTO enrollment "
            "(student_person_id, course_id, section_no) "
            "VALUES (%s, %s, %s)",
            (person_id, course_id, section_no),
        )
    # COMMIT happens automatically on clean exit


with psycopg.connect(conn_str) as conn:
    # --- Successful enrollment ---
    print("=== Successful enrollment ===")
    enroll(conn, 4, "ENPM818T", "0101")

    with conn.cursor() as cur:
        cur.execute(
            "SELECT capacity FROM course_section "
            "WHERE course_id = %s AND section_no = %s",
            ("ENPM818T", "0101"),
        )
        print(f"Capacity after enroll: {cur.fetchone()[0]}")

        cur.execute(
            "SELECT * FROM enrollment "
            "WHERE student_person_id = %s AND course_id = %s",
            (4, "ENPM818T"),
        )
        print(f"Enrollment row: {cur.fetchone()}")

    # --- Failed enrollment: FK violation triggers automatic ROLLBACK ---
    print("\n=== Failed enrollment (person_id=999) ===")
    try:
        enroll(conn, 999, "ENPM818T", "0101")
    except psycopg.errors.ForeignKeyViolation as e:
        print(f"Caught: {e.diag.message_primary}")

    with conn.cursor() as cur:
        cur.execute(
            "SELECT capacity FROM course_section "
            "WHERE course_id = %s AND section_no = %s",
            ("ENPM818T", "0101"),
        )
        print(f"Capacity after rollback: {cur.fetchone()[0]}")

    # --- Cleanup: remove the enrollment we just created ---
    with conn.transaction():
        conn.execute(
            "DELETE FROM enrollment "
            "WHERE student_person_id = %s AND course_id = %s AND section_no = %s",
            (4, "ENPM818T", "0101"),
        )
        conn.execute(
            "UPDATE course_section SET capacity = capacity + 1 "
            "WHERE course_id = %s AND section_no = %s",
            ("ENPM818T", "0101"),
        )
    print("\nCleanup done.")
