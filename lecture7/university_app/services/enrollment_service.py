"""
university_app/services/enrollment_service.py
Rules: no cur.execute() calls outside of methods that own a transaction,
       no input() calls (those belong in cli/menu.py).
Translates database exceptions into domain errors (ValueError) for the CLI.
"""

from psycopg.errors import ForeignKeyViolation, UniqueViolation

from config.database import DatabaseConfig
from repositories.person_repo import PersonRepository
from repositories.student_repo import StudentRepository


class EnrollmentService:

    def __init__(self) -> None:
        self._person_repo = PersonRepository()
        self._student_repo = StudentRepository()

    # ------------------------------------------------------------------
    # Student registration (ISA chain: person -> student)
    # ------------------------------------------------------------------

    def register_student(
        self,
        first_name: str,
        last_name: str,
        date_of_birth: str,
        student_id: str,
        admission_date: str,
        academic_standing: str = "Good Standing",
    ) -> dict:
        """
        Insert a person row (RETURNING person_id) then insert the student
        row inside a single conn.transaction() block.
        Returns the new student row as a dict.
        """
        try:
            with DatabaseConfig.get_connection() as conn:
                with conn.transaction():
                    # Step 1: insert into person and capture the generated PK
                    with conn.cursor() as cur:
                        cur.execute(
                            "INSERT INTO person "
                            "(first_name, last_name, date_of_birth) "
                            "VALUES (%s, %s, %s) "
                            "RETURNING person_id",
                            (first_name, last_name, date_of_birth),
                        )
                        person_id = cur.fetchone()[0]

                    # Step 2: insert into student using the returned PK
                    self._student_repo.create(
                        conn,
                        person_id,
                        student_id,
                        admission_date,
                        academic_standing,
                    )

                # conn.transaction() committed here on clean exit
                return self._student_repo.find_by_id(person_id)

        except UniqueViolation as exc:
            raise ValueError(f"Student ID already exists: {student_id}") from exc
        except ForeignKeyViolation as exc:
            raise ValueError("Referenced row does not exist.") from exc

    # ------------------------------------------------------------------
    # Course enrollment with FOR UPDATE to prevent lost updates
    # ------------------------------------------------------------------

    def enroll_student(
        self,
        person_id: int,
        course_id: str,
        section_no: str,
    ) -> None:
        """
        Lock the course_section row with FOR UPDATE, check capacity,
        decrement, and insert the enrollment row -- all atomically.
        Raises ValueError for business-rule violations.
        Raises ValueError (wrapping psycopg errors) for constraint violations.
        """
        try:
            with DatabaseConfig.get_connection() as conn:
                with conn.transaction():
                    with conn.cursor() as cur:
                        # Lock the row to prevent concurrent over-enrollment
                        cur.execute(
                            "SELECT capacity "
                            "FROM course_section "
                            "WHERE course_id = %s "
                            "  AND section_no = %s "
                            "FOR UPDATE",
                            (course_id, section_no),
                        )
                        row = cur.fetchone()

                        if row is None:
                            raise ValueError(
                                f"Section not found: {course_id} {section_no}"
                            )
                        if row[0] <= 0:
                            raise ValueError(
                                f"Section is full: {course_id} {section_no}"
                            )

                        # Decrement capacity and insert enrollment atomically
                        cur.execute(
                            "UPDATE course_section "
                            "SET capacity = capacity - 1 "
                            "WHERE course_id = %s AND section_no = %s",
                            (course_id, section_no),
                        )
                        cur.execute(
                            "INSERT INTO enrollment "
                            "(student_person_id, course_id, section_no) "
                            "VALUES (%s, %s, %s)",
                            (person_id, course_id, section_no),
                        )

        except UniqueViolation as exc:
            raise ValueError(
                f"Student {person_id} is already enrolled in "
                f"{course_id} {section_no}."
            ) from exc
        except ForeignKeyViolation as exc:
            raise ValueError(
                f"Student {person_id} or section {course_id}/{section_no} "
                f"does not exist."
            ) from exc
