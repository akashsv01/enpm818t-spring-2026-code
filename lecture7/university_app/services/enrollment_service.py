from psycopg.errors import ForeignKeyViolation, UniqueViolation

from config.database import DatabaseConfig


class EnrollmentService:

    def enroll_student(self, person_id: int,
                       course_id: str, section_no: str) -> None:
        """
        Atomically enroll a student: check capacity with FOR UPDATE,
        decrement capacity, and insert enrollment row.

        Raises ValueError on business rule violations.
        """
        with DatabaseConfig.get_connection() as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    # Lock the section row and read capacity
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
