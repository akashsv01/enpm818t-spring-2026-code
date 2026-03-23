from dataclasses import dataclass
from datetime import date


@dataclass
class Person:
    person_id:     int
    first_name:    str
    last_name:     str
    date_of_birth: date | None = None

    @classmethod
    def from_row(cls, row: dict) -> "Person":
        """Create a Person from a dict row returned by psycopg3."""
        return cls(
            person_id=row["person_id"],
            first_name=row["first_name"],
            last_name=row["last_name"],
            date_of_birth=row.get("date_of_birth"),
        )
