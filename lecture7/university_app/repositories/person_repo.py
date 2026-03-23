from psycopg.rows import dict_row

from config.database import DatabaseConfig
from models.person import Person


class PersonRepository:

    def find_by_id(self, person_id: int) -> Person | None:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT * FROM person WHERE person_id = %s",
                    (person_id,),
                )
                row = cur.fetchone()
                return Person.from_row(row) if row else None

    def find_all(self, limit: int = 20, offset: int = 0) -> list[Person]:
        with DatabaseConfig.get_connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT * FROM person ORDER BY person_id "
                    "LIMIT %s OFFSET %s",
                    (limit, offset),
                )
                return [Person.from_row(row) for row in cur.fetchall()]

    def create(self, first_name: str, last_name: str,
               date_of_birth: str | None = None) -> int:
        """Insert a person and return the generated person_id."""
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
