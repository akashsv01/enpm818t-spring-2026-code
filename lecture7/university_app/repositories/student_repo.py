from psycopg.rows import dict_row

from config.database import DatabaseConfig
from models.student import Student


class StudentRepository:

    def find_by_id(self, person_id: int) -> Student | None:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT * FROM student WHERE person_id = %s",
                    (person_id,),
                )
                row = cur.fetchone()
                return Student.from_row(row) if row else None

    def find_all(self, limit: int = 20, offset: int = 0) -> list[Student]:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT * FROM student ORDER BY person_id "
                    "LIMIT %s OFFSET %s",
                    (limit, offset),
                )
                return [Student.from_row(row) for row in cur.fetchall()]

    def create(self, person_id: int, student_id: str,
               admission_date: str, academic_standing: str,
               gpa: float | None = None) -> Student | None:
        """Insert a student row and return it."""
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "INSERT INTO student "
                    "(person_id, student_id, admission_date, "
                    " academic_standing, gpa) "
                    "VALUES (%s, %s, %s, %s, %s) "
                    "RETURNING *",
                    (person_id, student_id, admission_date,
                     academic_standing, gpa),
                )
                row = cur.fetchone()
                conn.commit()
                return Student.from_row(row) if row else None

    def delete(self, person_id: int) -> bool:
        """Delete a student by person_id. Returns True if a row was deleted."""
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM student WHERE person_id = %s",
                    (person_id,),
                )
                conn.commit()
                return cur.rowcount > 0
