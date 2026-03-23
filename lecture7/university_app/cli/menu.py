from repositories.person_repo import PersonRepository
from repositories.student_repo import StudentRepository
from services.enrollment_service import EnrollmentService


def main():
    person_repo = PersonRepository()
    student_repo = StudentRepository()
    svc = EnrollmentService()

    while True:
        print("\n=== University Management System ===\n")
        print("1. Add student")
        print("2. Find student by ID")
        print("3. Enroll student in section")
        print("4. List all students")
        print("5. Exit")
        choice = input("\nSelect option: ").strip()

        if choice == "1":
            first = input("First name: ").strip()
            last = input("Last name: ").strip()
            dob = input("Date of birth (YYYY-MM-DD, or blank): ").strip() or None
            sid = input("Student ID: ").strip()
            admission = input("Admission date (YYYY-MM-DD): ").strip()
            standing = input("Standing (Good Standing/Probation/Suspended/Dismissed): ").strip()

            try:
                pid = person_repo.create(first, last, dob)
                student = student_repo.create(pid, sid, admission, standing)
                print(f"\nCreated: {student}")
            except Exception as e:
                print(f"\nError: {e}")

        elif choice == "2":
            pid = input("Person ID: ").strip()
            try:
                student = student_repo.find_by_id(int(pid))
                if student:
                    print(f"\n{student}")
                else:
                    print("\nNot found.")
            except ValueError:
                print("\nInvalid ID.")

        elif choice == "3":
            try:
                pid = int(input("Person ID: ").strip())
                cid = input("Course ID: ").strip()
                sec = input("Section: ").strip()
                svc.enroll_student(pid, cid, sec)
                print("\nEnrolled successfully.")
            except ValueError as e:
                print(f"\nError: {e}")

        elif choice == "4":
            students = student_repo.find_all()
            if not students:
                print("\nNo students found.")
            else:
                print(f"\n{'ID':>4}  {'Student ID':<12} {'Standing':<16} {'GPA'}")
                print("-" * 48)
                for s in students:
                    gpa = f"{s.gpa:.2f}" if s.gpa is not None else "N/A"
                    print(f"{s.person_id:>4}  {s.student_id:<12} {s.academic_standing:<16} {gpa}")

        elif choice == "5":
            print("Goodbye.")
            break

        else:
            print("\nInvalid option.")
