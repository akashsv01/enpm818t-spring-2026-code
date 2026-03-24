"""
university_app/models/student.py
Pure data container. No database calls.
Field names match student table column names exactly.
"""

from dataclasses import dataclass
from datetime import date


@dataclass
class Student:
    person_id:         int
    student_id:        str
    admission_date:    date
    academic_standing: str
    gpa:               float | None = None

    @classmethod
    def from_row(cls, row: dict) -> "Student":
        return cls(**row)
