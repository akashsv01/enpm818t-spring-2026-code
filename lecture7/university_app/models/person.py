"""
university_app/models/person.py
Pure data container. No database calls.
Field names match person table column names exactly.
"""

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
        return cls(**row)
