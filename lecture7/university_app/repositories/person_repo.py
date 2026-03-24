"""
university_app/repositories/person_repo.py
Rules: no business logic, no user I/O.
Each method runs exactly one query and returns the result.
"""

from psycopg.rows import dict_row

from config.database import DatabaseConfig
from models.person import Person


class PersonRepository:

    def find_by_id(self, person_id: int) -> dict | None:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT person_id, first_name, last_name, date_of_birth "
                    "FROM person "
                    "WHERE person_id = %s",
                    (person_id,),
                )
                return cur.fetchone()

    def find_all(self) -> list[dict]:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT person_id, first_name, last_name, date_of_birth "
                    "FROM person "
                    "ORDER BY person_id"
                )
                return cur.fetchall()

    def create(
        self,
        first_name: str,
        last_name: str,
        date_of_birth: str | None,
    ) -> int:
        """
        Insert a new person row and return the generated person_id.
        Uses RETURNING to capture the identity value atomically.
        """
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO person (first_name, last_name, date_of_birth) "
                    "VALUES (%s, %s, %s) "
                    "RETURNING person_id",
                    (first_name, last_name, date_of_birth),
                )
                row = cur.fetchone()
                conn.commit()
                return row[0]
