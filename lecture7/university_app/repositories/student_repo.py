"""
university_app/repositories/student_repo.py
Rules: no business logic, no user I/O.
Each method runs exactly one query and returns the result.
"""

from psycopg.rows import dict_row

from config.database import DatabaseConfig


class StudentRepository:

    def find_by_id(self, person_id: int) -> dict | None:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT person_id, student_id, admission_date, "
                    "       academic_standing, gpa "
                    "FROM student "
                    "WHERE person_id = %s",
                    (person_id,),
                )
                return cur.fetchone()
        # fetchone() returns None if the row does not exist.
        # Handle that case in the service layer, not here.

    def find_by_student_id(self, student_id: str) -> dict | None:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT person_id, student_id, admission_date, "
                    "       academic_standing, gpa "
                    "FROM student "
                    "WHERE student_id = %s",
                    (student_id,),
                )
                return cur.fetchone()

    def find_all(self) -> list[dict]:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT person_id, student_id, admission_date, "
                    "       academic_standing, gpa "
                    "FROM student "
                    "ORDER BY person_id"
                )
                return cur.fetchall()
        # fetchall() returns [] if no rows match -- never None.

    def create(
        self,
        conn,
        person_id: int,
        student_id: str,
        admission_date: str,
        academic_standing: str,
    ) -> None:
        """
        Insert a student row inside an already-open transaction (conn).
        The caller (service layer) owns the transaction boundary.
        """
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO student "
                "(person_id, student_id, admission_date, academic_standing) "
                "VALUES (%s, %s, %s, %s)",
                (person_id, student_id, admission_date, academic_standing),
            )
