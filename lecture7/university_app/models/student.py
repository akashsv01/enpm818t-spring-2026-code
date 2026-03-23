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
        """Create a Student from a dict row returned by psycopg3."""
        return cls(
            person_id=row["person_id"],
            student_id=row["student_id"],
            admission_date=row["admission_date"],
            academic_standing=row["academic_standing"],
            gpa=float(row["gpa"]) if row.get("gpa") is not None else None,
        )
