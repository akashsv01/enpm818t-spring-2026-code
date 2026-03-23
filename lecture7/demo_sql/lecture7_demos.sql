-- ============================================================
-- ENPM818T L7 Demo SQL Script
-- university_db
-- Run against a fresh database: createdb university_db
-- ============================================================

-- ============================================================
-- Schema Setup (run once before any demo)
-- ============================================================

DROP TABLE IF EXISTS course_prereq CASCADE;
DROP TABLE IF EXISTS enrollment     CASCADE;
DROP TABLE IF EXISTS course_section  CASCADE;
DROP TABLE IF EXISTS course          CASCADE;
DROP TABLE IF EXISTS grad_student    CASCADE;
DROP TABLE IF EXISTS professor       CASCADE;
DROP TABLE IF EXISTS student         CASCADE;
DROP TABLE IF EXISTS department      CASCADE;
DROP TABLE IF EXISTS person          CASCADE;
DROP TABLE IF EXISTS dept_mapping    CASCADE;
DROP TABLE IF EXISTS honors_student  CASCADE;
DROP TABLE IF EXISTS student_archive CASCADE;

CREATE TABLE person (
    person_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name     VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50) NOT NULL,
    date_of_birth  DATE
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE          -- FK added after professor is created (circular dep)
);

CREATE TABLE student (
    person_id         INTEGER PRIMARY KEY
        REFERENCES person (person_id) ON DELETE CASCADE,
    student_id        VARCHAR(20) NOT NULL UNIQUE,
    admission_date    DATE        NOT NULL,
    academic_standing VARCHAR(30) NOT NULL,
    gpa               NUMERIC(3,2),
    CONSTRAINT chk_gpa
        CHECK (gpa >= 0.0 AND gpa <= 4.0),
    CONSTRAINT chk_standing
        CHECK (academic_standing IN (
            'Good Standing', 'Probation',
            'Suspended',     'Dismissed'))
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id) ON DELETE CASCADE,
    dept_id   INTEGER REFERENCES department (dept_id),
    hire_date DATE    NOT NULL,
    rank_code VARCHAR(20) NOT NULL,
    CONSTRAINT chk_rank
        CHECK (rank_code IN ('Assistant', 'Associate', 'Full'))
);

-- Resolve circular dependency: department.chair_id -> professor.person_id
ALTER TABLE department
    ADD CONSTRAINT fk_dept_chair
        FOREIGN KEY (chair_id)
            REFERENCES professor (person_id)
            ON DELETE SET NULL;

CREATE TABLE grad_student (
    person_id  INTEGER PRIMARY KEY
        REFERENCES student (person_id) ON DELETE CASCADE,
    advisor_id INTEGER REFERENCES professor (person_id)
);

CREATE TABLE course (
    course_id VARCHAR(10)  PRIMARY KEY,
    dept_id   INTEGER      NOT NULL REFERENCES department (dept_id),
    title     VARCHAR(150) NOT NULL,
    credits   INTEGER      NOT NULL
);

CREATE TABLE course_prereq (
    successor_id VARCHAR(10) NOT NULL REFERENCES course (course_id),
    prereq_id    VARCHAR(10) NOT NULL REFERENCES course (course_id)
        ON DELETE RESTRICT,
    CONSTRAINT pk_course_prereq PRIMARY KEY (successor_id, prereq_id),
    CONSTRAINT fk_cp_prereq
        FOREIGN KEY (prereq_id)
            REFERENCES course (course_id)
            ON DELETE RESTRICT
);

CREATE TABLE course_section (
    course_id  VARCHAR(10) NOT NULL REFERENCES course (course_id),
    section_no VARCHAR(10) NOT NULL,
    capacity   INTEGER     NOT NULL DEFAULT 30,
    CONSTRAINT pk_course_section PRIMARY KEY (course_id, section_no)
);

CREATE TABLE enrollment (
    student_person_id INTEGER     NOT NULL
        REFERENCES student (person_id) ON DELETE CASCADE,
    course_id         VARCHAR(10) NOT NULL,
    section_no        VARCHAR(10) NOT NULL,
    grade             VARCHAR(3),
    CONSTRAINT pk_enrollment
        PRIMARY KEY (student_person_id, course_id, section_no),
    CONSTRAINT fk_enroll_section
        FOREIGN KEY (course_id, section_no)
            REFERENCES course_section (course_id, section_no)
            ON DELETE CASCADE
);


-- ============================================================
-- Seed data (minimum needed for all demos)
-- ============================================================
BEGIN;

-- Departments
INSERT INTO department (dept_name)
    VALUES ('Computer Science'),
           ('Mathematics'),
           ('Mechanical Engineering'),
           ('Electrical Engineering');

-- Courses
INSERT INTO course VALUES ('ENPM818T', 1, 'Data Storage and Databases', 3);
INSERT INTO course VALUES ('ENPM605',  1, 'Python for Robotics', 3);
INSERT INTO course VALUES ('ENPM702',  1, 'Robot Programming', 3);

-- Prerequisites
INSERT INTO course_prereq VALUES ('ENPM818T', 'ENPM605');

-- Course sections
INSERT INTO course_section VALUES ('ENPM818T', '0101', 30);
INSERT INTO course_section VALUES ('ENPM605',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM702',  '0101', 30);

-- Persons
INSERT INTO person (first_name, last_name, date_of_birth)
    VALUES ('Alice',   'Johnson', '1998-04-12'),  -- 1
           ('Bob',     'Smith',   '1999-07-22'),  -- 2
           ('Carol',   'Davis',   '1980-03-15'),  -- 3
           ('David',   'Lee',     '2000-11-30'),  -- 4
           ('Eve',     'Brown',   '2001-01-10'),  -- 5
           ('Frank',   'Wilson',  '1975-06-05'),  -- 6
           ('Grace',   'Taylor',  '1982-09-20'),  -- 7
           ('Hank',    'Anderson','1990-12-01'),  -- 8
           ('Irene',   'Thomas',  '1985-04-18');  -- 9

-- Students (person_id 1, 2, 4, 5)
INSERT INTO student VALUES (1, '117453210', '2024-08-26', 'Good Standing', 3.75);
INSERT INTO student VALUES (2, '117453211', '2024-08-26', 'Good Standing', 1.85);
INSERT INTO student VALUES (4, '117453213', '2023-08-28', 'Good Standing', 3.20);
INSERT INTO student VALUES (5, '117453214', '2023-08-28', 'Good Standing', 1.92);

-- Professors (person_id 3, 6, 7, 8, 9)
INSERT INTO professor VALUES (3, 1, '2017-08-01', 'Associate');
INSERT INTO professor VALUES (6, 2, '2015-01-10', 'Full');
INSERT INTO professor VALUES (7, 1, '2019-01-15', 'Associate');
INSERT INTO professor VALUES (8, 3, '2022-08-01', 'Assistant');
INSERT INTO professor VALUES (9, 4, '2021-03-20', 'Associate');

-- Department chairs (professor chairs 0 or 1 department)
UPDATE department SET chair_id = 3 WHERE dept_id = 1;  -- Carol chairs CS
UPDATE department SET chair_id = 6 WHERE dept_id = 2;  -- Frank chairs Math
-- Mech Eng and EE have no chair (chair_id stays NULL)

-- Enrollments
INSERT INTO enrollment VALUES (1, 'ENPM818T', '0101', 'A');
INSERT INTO enrollment VALUES (2, 'ENPM818T', '0101', 'B+');
INSERT INTO enrollment VALUES (1, 'ENPM605',  '0101', 'A-');
INSERT INTO enrollment VALUES (4, 'ENPM702',  '0101', 'B');
INSERT INTO enrollment VALUES (5, 'ENPM818T', '0101', 'A');

COMMIT;


-- ============================================================
-- Demo 2: INSERT ... RETURNING and ISA chain
-- ============================================================

-- Insert a new person and capture the generated PK
INSERT INTO person (first_name, last_name, date_of_birth)
    VALUES ('Zara', 'Patel', '2002-05-14')
    RETURNING person_id;
-- Result: person_id = 10

-- Use the returned value to insert the student row
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');

-- Verify
SELECT * FROM student WHERE person_id = 10;

-- Attempt with non-existent person_id: FK violation
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (99, '117453299', '2025-08-25', 'Good Standing');
-- ERROR: insert or update on table "student" violates foreign key constraint


-- ============================================================
-- Demo 4: ON CONFLICT (DO NOTHING and DO UPDATE)
-- ============================================================

-- First insert succeeds
INSERT INTO department (dept_name) VALUES ('Computer Science');
-- ERROR: duplicate key value violates unique constraint

-- ON CONFLICT DO NOTHING: skip silently
INSERT INTO department (dept_name)
    VALUES ('Computer Science')
    ON CONFLICT DO NOTHING;
-- 0 rows inserted, no error

-- ON CONFLICT DO UPDATE (upsert)
INSERT INTO course (course_id, title, credits, dept_id)
    VALUES ('ENPM818T', 'Databases and Data Storage', 3, 1)
    ON CONFLICT (course_id) DO UPDATE
        SET title   = EXCLUDED.title,
            credits = EXCLUDED.credits;

-- Verify the title was updated
SELECT course_id, title FROM course WHERE course_id = 'ENPM818T';


-- ============================================================
-- Demo 5: Safe UPDATE workflow
-- ============================================================

-- Step 1: Preview the target set
SELECT person_id, gpa, academic_standing
FROM student
WHERE gpa < 2.0;

-- Step 2: UPDATE with RETURNING
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;

-- Dangerous: UPDATE without WHERE (inside BEGIN/ROLLBACK)
BEGIN;
    UPDATE student SET academic_standing = 'Probation';
    SELECT person_id, academic_standing FROM student;
    -- All rows are now 'Probation'!
ROLLBACK;
-- Restored to original state

-- Verify rollback worked
SELECT person_id, academic_standing FROM student;


-- ============================================================
-- Demo 8: DELETE with CASCADE and RETURNING
-- ============================================================

-- Check Alice's enrollment rows before deleting
SELECT * FROM enrollment WHERE student_person_id = 1;

-- Capture enrollment rows before they disappear
DELETE FROM enrollment
    WHERE student_person_id = 1
    RETURNING student_person_id, course_id, grade;

-- Delete Alice from person; CASCADE removes student row automatically
DELETE FROM person WHERE person_id = 1;

-- Confirm cascade removed the student row
SELECT * FROM student WHERE person_id = 1;
-- 0 rows


-- ============================================================
-- Demo 9: Exercise 1 walkthrough
-- (Instructor walks through each sub-task live in DataGrip)
-- ============================================================

-- Re-insert Alice for subsequent demos
INSERT INTO person (first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (1, 'Alice', 'Johnson', '1998-04-12');

INSERT INTO student VALUES (1, '117453210', '2024-08-26', 'Good Standing', 3.75);

INSERT INTO enrollment VALUES (1, 'ENPM818T', '0101', 'A');
INSERT INTO enrollment VALUES (1, 'ENPM605',  '0101', 'A-');

-- Reset academic_standing for demo 5 changes
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing = 'Probation';


-- ============================================================
-- Demo 10: Transactions -- COMMIT vs ROLLBACK
-- ============================================================

-- Successful enrollment
BEGIN;
    UPDATE course_section
        SET capacity = capacity - 1
        WHERE course_id  = 'ENPM818T'
          AND section_no = '0101';
    INSERT INTO enrollment
        (student_person_id, course_id, section_no)
        VALUES (4, 'ENPM818T', '0101');
COMMIT;

-- Verify
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
SELECT * FROM enrollment WHERE student_person_id = 4;

-- Failed enrollment: FK violation forces ROLLBACK
BEGIN;
    UPDATE course_section
        SET capacity = capacity - 1
        WHERE course_id  = 'ENPM818T'
          AND section_no = '0101';
    INSERT INTO enrollment
        (student_person_id, course_id, section_no)
        VALUES (999, 'ENPM818T', '0101');
    -- FK violation: person 999 does not exist
ROLLBACK;

-- Verify capacity was restored
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- Demo 11: SAVEPOINT -- partial rollback
-- ============================================================

-- Clean up enrollment for student 4 from demo 10
DELETE FROM enrollment WHERE student_person_id = 4 AND course_id = 'ENPM818T';

-- Restore capacity
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

BEGIN;
    INSERT INTO enrollment VALUES (1, 'ENPM702', '0101', NULL);
    INSERT INTO enrollment VALUES (2, 'ENPM605', '0101', NULL);
    INSERT INTO enrollment VALUES (4, 'ENPM605', '0101', NULL);

    SAVEPOINT after_three;

    INSERT INTO enrollment VALUES (4, 'ENPM605', '0101', NULL);
    -- FAIL: duplicate PK

    ROLLBACK TO SAVEPOINT after_three;
    -- Rows 1,2,4 still here; failed insert gone

    INSERT INTO enrollment VALUES (5, 'ENPM605', '0101', NULL);
COMMIT;

-- Verify exactly 4 new rows were committed
SELECT * FROM enrollment ORDER BY student_person_id, course_id;


-- ============================================================
-- Demo 13: Minimal Python connection
-- (Run demo13_connect.py instead -- this is just the SQL to
--  verify from psql after running the Python script)
-- ============================================================

SELECT count(*) FROM pg_stat_activity
    WHERE datname = 'university_db';


-- ============================================================
-- Demo 15: Transactions in Python
-- (Run demo15_transaction.py instead)
-- ============================================================

-- Verify after running the Python script:
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
SELECT * FROM enrollment
    WHERE student_person_id = 4 AND course_id = 'ENPM818T';


-- ============================================================
-- Demo 17: EnrollmentService
-- (Run demo17_enrollment_service.py instead)
-- ============================================================

-- Set capacity to 2 to test exhaustion quickly
UPDATE course_section SET capacity = 2
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- Verify after running the Python script:
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- Cleanup: reset capacity for subsequent use
-- ============================================================
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
