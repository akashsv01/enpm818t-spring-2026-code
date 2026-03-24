"""
university_app/cli/menu.py
Rules: no SQL, no business logic -- only I/O and formatting.
Catches ValueError from services and prints user-friendly messages.
"""

from services.enrollment_service import EnrollmentService


def _print_menu() -> None:
    print("\n--- University App ---")
    print("1. Register new student")
    print("2. Find student by person ID")
    print("3. Enroll student in course section")
    print("4. List all students")
    print("0. Exit")
    print("----------------------")


def main() -> None:
    svc = EnrollmentService()

    while True:
        _print_menu()
        choice = input("Select option: ").strip()

        if choice == "0":
            print("Goodbye.")
            break

        elif choice == "1":
            first_name       = input("First name:        ").strip()
            last_name        = input("Last name:         ").strip()
            date_of_birth    = input("Date of birth (YYYY-MM-DD): ").strip() or None
            student_id       = input("Student ID:        ").strip()
            admission_date   = input("Admission date (YYYY-MM-DD): ").strip()
            try:
                student = svc.register_student(
                    first_name, last_name, date_of_birth,
                    student_id, admission_date,
                )
                print(f"Registered: {student}")
            except ValueError as exc:
                print(f"Error: {exc}")

        elif choice == "2":
            try:
                person_id = int(input("Person ID: ").strip())
            except ValueError:
                print("Error: person ID must be an integer.")
                continue
            student = svc._student_repo.find_by_id(person_id)
            if student is None:
                print(f"No student found with person_id = {person_id}.")
            else:
                print(student)

        elif choice == "3":
            try:
                person_id = int(input("Person ID:  ").strip())
            except ValueError:
                print("Error: person ID must be an integer.")
                continue
            course_id  = input("Course ID:  ").strip()
            section_no = input("Section no: ").strip()
            try:
                svc.enroll_student(person_id, course_id, section_no)
                print("Enrolled successfully.")
            except ValueError as exc:
                print(f"Error: {exc}")

        elif choice == "4":
            students = svc._student_repo.find_all()
            if not students:
                print("No students found.")
            else:
                for s in students:
                    print(s)

        else:
            print("Invalid option. Please choose 0-4.")
