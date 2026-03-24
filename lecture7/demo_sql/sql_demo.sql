-- ============================================================
-- ENPM818T L7 Demo SQL Script
-- university_db
-- Run against a fresh database: createdb university_db
-- ============================================================
-- DEMO NUMBERING (matches slide \demostep{} counters):
--   Demo 1  = INSERT ... RETURNING (ISA chain)
--   Demo 2  = ON CONFLICT DO NOTHING
--   Demo 3a = ON CONFLICT DO UPDATE (upsert)        -- slide demostep{3} #1
--   Demo 3b = Safe UPDATE workflow                  -- slide demostep{3} #2
--             NOTE: two slides share demostep{3}; see instructor note below
--   Demo 4  = DELETE CASCADE and RETURNING
--   Demo 5  = Exercise 1 walkthrough
--   Demo 6  = COMMIT: happy path
--   Demo 7  = ROLLBACK: failed enrollment
--   Demo 8  = SAVEPOINT: partial rollback
--   Demo 9  = psycopg3 minimal connection (Python -- run extra/standalone_test.py)
--   Demo 10 = psycopg3 conn.transaction()   (Python -- run extra/demo_transaction.py)
--   Demo 11 = EnrollmentService             (Python -- run extra/demo_enrollment_service.py)
-- ============================================================

-- ============================================================
-- Schema Setup
-- Run this section once before any demo (up to line ~120).
-- Drops and recreates all tables and loads seed data.
-- ============================================================

DROP TABLE IF EXISTS course_prereq    CASCADE;
DROP TABLE IF EXISTS enrollment       CASCADE;
DROP TABLE IF EXISTS course_section   CASCADE;
DROP TABLE IF EXISTS course           CASCADE;
DROP TABLE IF EXISTS grad_student     CASCADE;
DROP TABLE IF EXISTS professor        CASCADE;
DROP TABLE IF EXISTS student          CASCADE;
DROP TABLE IF EXISTS department       CASCADE;
DROP TABLE IF EXISTS person           CASCADE;
DROP TABLE IF EXISTS dept_mapping     CASCADE;
DROP TABLE IF EXISTS honors_student   CASCADE;
DROP TABLE IF EXISTS student_archive  CASCADE;
DROP TABLE IF EXISTS on_call          CASCADE;

CREATE TABLE person (
    person_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    date_of_birth DATE
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE
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
    successor_id VARCHAR(10) NOT NULL
        REFERENCES course (course_id) ON DELETE RESTRICT,
    prereq_id    VARCHAR(10) NOT NULL,
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

CREATE TABLE dept_mapping (
    person_id INTEGER NOT NULL,
    dept_id   INTEGER NOT NULL REFERENCES department (dept_id)
);

CREATE TABLE honors_student (
    person_id  INTEGER PRIMARY KEY
        REFERENCES student (person_id) ON DELETE CASCADE,
    student_id VARCHAR(20) NOT NULL,
    gpa        NUMERIC(3,2)
);

CREATE TABLE student_archive (
    person_id         INTEGER NOT NULL,
    student_id        VARCHAR(20) NOT NULL,
    admission_date    DATE,
    academic_standing VARCHAR(30),
    gpa               NUMERIC(3,2)
);

-- Used in the write-skew (Serializable) demo
CREATE TABLE on_call (
    doctor VARCHAR(10) PRIMARY KEY
);


-- ============================================================
-- Seed Data
-- ============================================================
BEGIN;

INSERT INTO department (dept_name)
    VALUES ('Computer Science'),       -- dept_id = 1
           ('Mathematics'),            -- dept_id = 2
           ('Mechanical Engineering'), -- dept_id = 3
           ('Electrical Engineering'); -- dept_id = 4

-- ENPM601 is needed for the ON DELETE RESTRICT demo (course_prereq chain)
INSERT INTO course VALUES ('ENPM601',  1, 'Foundations',                3);
INSERT INTO course VALUES ('ENPM605',  1, 'Python for Robotics',        3);
INSERT INTO course VALUES ('ENPM702',  1, 'Robot Programming',          3);
INSERT INTO course VALUES ('ENPM818T', 1, 'Data Storage and Databases', 3);

-- Prerequisite chain: ENPM818T requires ENPM605; ENPM605 requires ENPM601
-- This means ENPM605 appears as both prereq_id and successor_id -- needed
-- so the RESTRICT demo shows both OR branches are required.
INSERT INTO course_prereq VALUES ('ENPM605',  'ENPM601');
INSERT INTO course_prereq VALUES ('ENPM818T', 'ENPM605');

INSERT INTO course_section VALUES ('ENPM601',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM605',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM702',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM818T', '0101', 30);

-- Persons 1-9 (staff + students); person 10 reserved as demo/throwaway student
INSERT INTO person (first_name, last_name, date_of_birth)
    VALUES ('Alice',  'Johnson',  '1998-04-12'),  -- 1  student
           ('Bob',    'Smith',    '1999-07-22'),  -- 2  student
           ('Carol',  'Davis',    '1980-03-15'),  -- 3  professor
           ('David',  'Lee',      '2000-11-30'),  -- 4  student
           ('Eve',    'Brown',    '2001-01-10'),  -- 5  student
           ('Frank',  'Wilson',   '1975-06-05'),  -- 6  professor
           ('Grace',  'Taylor',   '1982-09-20'),  -- 7  professor
           ('Hank',   'Anderson', '1990-12-01'),  -- 8  professor
           ('Irene',  'Thomas',   '1985-04-18'),  -- 9  professor
           ('Zara',   'Patel',    '2002-05-14');  -- 10 demo/throwaway student

-- Students: person_id 1, 2, 4, 5
INSERT INTO student VALUES (1, '117453210', '2024-08-26', 'Good Standing', 3.75);
INSERT INTO student VALUES (2, '117453211', '2024-08-26', 'Good Standing', 1.85);
INSERT INTO student VALUES (4, '117453213', '2023-08-28', 'Good Standing', 3.20);
INSERT INTO student VALUES (5, '117453214', '2023-08-28', 'Good Standing', 1.92);

-- Professors: person_id 3, 6, 7, 8, 9
INSERT INTO professor VALUES (3, 1, '2017-08-01', 'Associate');
INSERT INTO professor VALUES (6, 2, '2015-01-10', 'Full');
INSERT INTO professor VALUES (7, 1, '2019-01-15', 'Associate');
INSERT INTO professor VALUES (8, 3, '2022-08-01', 'Assistant');
INSERT INTO professor VALUES (9, 4, '2021-03-20', 'Associate');

UPDATE department SET chair_id = 3 WHERE dept_id = 1; -- Carol chairs CS
UPDATE department SET chair_id = 6 WHERE dept_id = 2; -- Frank chairs Math

-- Seed enrollments: Alice(1) and Bob(2) in ENPM818T; Alice(1) in ENPM605;
-- David(4) in ENPM702; Eve(5) in ENPM818T.
-- NOTE: David(4) is intentionally NOT enrolled in ENPM818T -- used for Demo 6.
INSERT INTO enrollment VALUES (1, 'ENPM818T', '0101', 'A');
INSERT INTO enrollment VALUES (2, 'ENPM818T', '0101', 'B+');
INSERT INTO enrollment VALUES (1, 'ENPM605',  '0101', 'A-');
INSERT INTO enrollment VALUES (4, 'ENPM702',  '0101', 'B');
INSERT INTO enrollment VALUES (5, 'ENPM818T', '0101', 'A');

INSERT INTO on_call VALUES ('A'), ('B');

COMMIT;

-- ============================================================
-- Verify seed (run after schema setup to confirm all is well)
-- ============================================================
SELECT 'person'     AS tbl, count(*) FROM person
UNION ALL SELECT 'student',    count(*) FROM student
UNION ALL SELECT 'professor',  count(*) FROM professor
UNION ALL SELECT 'course',     count(*) FROM course
UNION ALL SELECT 'enrollment', count(*) FROM enrollment;
-- Expected: person=10, student=4, professor=5, course=4, enrollment=5


-- ============================================================
-- SELECT PREVIEW (used throughout to verify DML results)
-- Run any of these at any point; they do not modify data.
-- ============================================================

SELECT * FROM student;
SELECT person_id, gpa, academic_standing FROM student;
SELECT person_id, gpa FROM student WHERE gpa < 2.0;
SELECT person_id, academic_standing FROM student WHERE academic_standing = 'Probation';
SELECT person_id, gpa FROM student ORDER BY gpa DESC;
SELECT COUNT(*) FROM enrollment WHERE course_id = 'ENPM818T';


-- ============================================================
-- Demo 1: INSERT -- single-row, multi-row, RETURNING, ISA chain
-- Slide: demostep{1}
-- State entering: person=10 rows, student=4 rows (1,2,4,5)
-- ============================================================

-- Single-row INSERT (department -- no identity col)
INSERT INTO department (dept_name) VALUES ('Philosophy');
SELECT dept_id, dept_name FROM department ORDER BY dept_id;

-- Multi-row INSERT
INSERT INTO department (dept_name)
    VALUES ('Linguistics'), ('History'), ('Sociology');
SELECT dept_id, dept_name FROM department ORDER BY dept_id;

-- Clean up the extra departments
DELETE FROM department WHERE dept_name IN ('Philosophy','Linguistics','History','Sociology');

-- INSERT ... RETURNING: the right way to thread a PK into an ISA child row
-- person 10 (Zara) already exists in seed -- use her as the demo student
-- Show the pattern using a NEW person first for pedagogical clarity:
INSERT INTO person (first_name, last_name, date_of_birth)
    VALUES ('Lena', 'Park', '2003-06-20')
    RETURNING person_id;
-- Returns person_id = 11

INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (11, '117453230', '2025-08-25', 'Good Standing');

SELECT * FROM student WHERE person_id = 11;

-- FK violation: person_id 99 does not exist
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (99, '117453299', '2025-08-25', 'Good Standing');
-- ERROR: violates foreign key constraint

-- Clean up Lena (person_id=11) -- not needed in subsequent demos
DELETE FROM person WHERE person_id = 11;
-- (CASCADE removes the student row automatically)

-- State after Demo 1: person=10, student=4 (1,2,4,5)  <-- back to seed


-- ============================================================
-- Demo 2: ON CONFLICT DO NOTHING
-- Slide: demostep{2}
-- State entering: unchanged from seed
-- ============================================================

-- Without ON CONFLICT: duplicate throws error
INSERT INTO department (dept_name) VALUES ('Computer Science');
-- ERROR: duplicate key value violates unique constraint

-- WITH ON CONFLICT DO NOTHING: silent skip
INSERT INTO department (dept_name)
    VALUES ('Computer Science')
    ON CONFLICT DO NOTHING;
-- 0 rows inserted, no error

SELECT dept_id, dept_name FROM department WHERE dept_name = 'Computer Science';
-- Row unchanged

-- State after Demo 2: unchanged


-- ============================================================
-- Demo 3a: ON CONFLICT DO UPDATE (upsert)
-- Slide: demostep{3} (first occurrence -- ON CONFLICT DO UPDATE slide)
-- State entering: unchanged
-- ============================================================

-- Upsert: update the title if the course already exists
INSERT INTO course (course_id, title, credits, dept_id)
    VALUES ('ENPM818T', 'Databases and Data Storage', 3, 1)
    ON CONFLICT (course_id) DO UPDATE
        SET title   = EXCLUDED.title,
            credits = EXCLUDED.credits;

-- Verify title changed
SELECT course_id, title FROM course WHERE course_id = 'ENPM818T';
-- Returns: 'Databases and Data Storage'

-- Restore original title immediately so subsequent demos see the right name
UPDATE course SET title = 'Data Storage and Databases'
    WHERE course_id = 'ENPM818T';

-- State after Demo 3a: unchanged (title restored)


-- ============================================================
-- Demo 3b: Safe UPDATE workflow
-- Slide: demostep{3} (second occurrence -- safe UPDATE slide)
-- NOTE: Two slides share demostep{3}. In DataGrip, run 3a and 3b
--       as separate named scripts or label them clearly.
-- State entering: students 2(gpa=1.85) and 5(gpa=1.92) both 'Good Standing'
-- ============================================================

-- Step 1: preview the target set (same WHERE as the UPDATE)
SELECT person_id, gpa, academic_standing
FROM student
WHERE gpa < 2.0;
-- Returns person_id 2 (1.85) and 5 (1.92)

-- Step 2: UPDATE with RETURNING to confirm exactly which rows change
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;
-- Returns exactly the two rows above

-- Dangerous variant: show the full-table overwrite inside BEGIN/ROLLBACK
BEGIN;
    UPDATE student SET academic_standing = 'Probation';
    SELECT person_id, academic_standing FROM student;
    -- All rows show 'Probation'
ROLLBACK;
-- The ROLLBACK undoes the full-table update.
-- The targeted UPDATE above (WHERE gpa < 2.0) was already committed
-- and is NOT rolled back by this ROLLBACK.

-- IMPORTANT: restore standing for students 2 and 5 NOW
-- so Demo 4 and beyond see a clean state.
UPDATE student SET academic_standing = 'Good Standing'
    WHERE person_id IN (2, 5);

-- Verify restored
SELECT person_id, academic_standing FROM student;

-- State after Demo 3b: all students back to 'Good Standing'


-- ============================================================
-- Demo 4: DELETE -- CASCADE behavior and RETURNING
-- Slide: demostep{4}
-- State entering: person 10 (Zara) exists in person but NOT in student yet.
--                 We use Zara as the throwaway student for the delete demo
--                 so core students (1,2,4,5) are never touched.
-- ============================================================

-- First insert Zara into student so the cascade demo is meaningful
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
INSERT INTO enrollment VALUES (10, 'ENPM818T', '0101', NULL);
INSERT INTO enrollment VALUES (10, 'ENPM605',  '0101', NULL);

-- Show what Zara's enrollment rows look like before deletion
SELECT * FROM enrollment WHERE student_person_id = 10;

-- Capture enrollment rows for audit before cascade removes them
DELETE FROM enrollment
    WHERE student_person_id = 10
    RETURNING student_person_id, course_id, grade;
-- Returns the two rows above

-- Delete Zara from person; CASCADE removes the student row automatically
DELETE FROM person WHERE person_id = 10;

-- Confirm cascade removed the student row
SELECT * FROM student WHERE person_id = 10;
-- 0 rows

-- Re-insert Zara so she is available as a fresh throwaway for Exercise 1
INSERT INTO person (first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14');

-- Verify
SELECT person_id, first_name FROM person WHERE person_id = 10;

-- State after Demo 4:
--   person 10 (Zara) exists but is NOT in student (student row was deleted)
--   Core students 1,2,4,5 untouched
--   Core enrollments untouched: (1,ENPM818T), (2,ENPM818T), (1,ENPM605),
--                                (4,ENPM702), (5,ENPM818T)


-- ============================================================
-- Demo 5: Exercise 1 walkthrough
-- Slide: demostep{5}
-- State entering: see above (Zara in person but not student; core rows intact)
-- ============================================================

-- Task 1: insert three new departments in a single statement
INSERT INTO department (dept_name)
    VALUES ('Linguistics'), ('History'), ('Art History');
SELECT dept_id, dept_name FROM department ORDER BY dept_id;

-- Task 2: insert a new person using RETURNING, then insert student row
-- person_id 10 (Zara) already exists -- use her
-- Re-insert her as a student using the existing person_id
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
SELECT * FROM student WHERE person_id = 10;

-- Task 3: safe UPDATE workflow (standing for low-GPA students)
-- After Demo 3b restore, students 2 and 5 are 'Good Standing' again
SELECT person_id, gpa, academic_standing FROM student WHERE gpa < 2.0;
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;

-- Dangerous variant inside BEGIN/ROLLBACK
BEGIN;
    UPDATE student SET academic_standing = 'Probation';
    SELECT person_id, academic_standing FROM student;
ROLLBACK;

-- Task 4: delete Zara (person_id=10) and confirm cascade
-- First verify the FK chain
-- \d+ student   <-- run this in psql, not DataGrip SQL console
DELETE FROM person WHERE person_id = 10;
SELECT * FROM student WHERE person_id = 10;
-- 0 rows -- cascade removed the student row

-- Clean up extra departments from Task 1
DELETE FROM department
    WHERE dept_name IN ('Linguistics', 'History', 'Art History');

-- Restore standing for students 2 and 5 (changed in Task 3)
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing = 'Probation';

-- Re-insert Zara one final time so she is available if needed later
INSERT INTO person (first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14');

-- State after Demo 5:
--   person 10 (Zara) in person but NOT in student
--   All students: 1,2,4,5 with 'Good Standing'
--   Core enrollments: (1,ENPM818T), (2,ENPM818T), (1,ENPM605),
--                     (4,ENPM702), (5,ENPM818T)
--   ENPM818T/0101 capacity = 30


-- ============================================================
-- Demo 6: COMMIT -- the happy path
-- Slide: demostep{6} (ROLLBACK slide says "Run Demo 6")
-- Uses person_id=4 (David) who is NOT yet enrolled in ENPM818T.
-- State entering: capacity=30, David NOT in ENPM818T/0101
-- ============================================================

BEGIN;
    UPDATE course_section
        SET capacity = capacity - 1
        WHERE course_id  = 'ENPM818T'
          AND section_no = '0101';
    INSERT INTO enrollment
        (student_person_id, course_id, section_no)
        VALUES (4, 'ENPM818T', '0101');
COMMIT;

-- Verify: capacity is 29, enrollment row exists
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29

SELECT student_person_id, course_id, section_no
FROM enrollment
WHERE student_person_id = 4 AND course_id = 'ENPM818T';
-- Expected: one row

-- State after Demo 6:
--   David(4) enrolled in ENPM818T/0101
--   ENPM818T/0101 capacity = 29


-- ============================================================
-- Demo 7: ROLLBACK -- failed enrollment
-- Slide: demostep{6} (same demostep as COMMIT -- both on ROLLBACK slide)
-- State entering: capacity=29 (from Demo 6)
-- ============================================================

BEGIN;
    UPDATE course_section
        SET capacity = capacity - 1
        WHERE course_id  = 'ENPM818T'
          AND section_no = '0101';
    -- capacity is now 28 inside this transaction
    INSERT INTO enrollment
        (student_person_id, course_id, section_no)
        VALUES (999, 'ENPM818T', '0101');
    -- FK violation: person 999 does not exist
ROLLBACK;
-- Both the UPDATE and the failed INSERT are undone.
-- Capacity goes back to 29.

-- Verify capacity restored
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29 (same as after Demo 6)

-- State after Demo 7:
--   ENPM818T/0101 capacity = 29 (unchanged from Demo 6)
--   David(4) still enrolled in ENPM818T (from Demo 6)


-- ============================================================
-- Demo 8: SAVEPOINT -- partial rollback
-- Slide: demostep{7}
-- Uses enrollment rows that do NOT yet exist:
--   Bob(2)   + ENPM702/0101  (seed has Bob only in ENPM818T and ENPM605 via Demo 3)
--             Wait -- after Demo 3b restore, Bob is NOT in ENPM605.
--             Seed: Bob(2) in ENPM818T only.
--   David(4) + ENPM818T/0101 (David enrolled by Demo 6 -- already exists!)
--
-- IMPORTANT: clean up Demo 6 enrollment first so the SAVEPOINT demo
-- can re-use David in ENPM818T as the intended duplicate failure.
-- ============================================================

-- Pre-cleanup: remove David's ENPM818T enrollment from Demo 6
-- and restore capacity so Demo 8 starts clean.
DELETE FROM enrollment
    WHERE student_person_id = 4 AND course_id = 'ENPM818T';
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- Verify clean state
SELECT student_person_id, course_id FROM enrollment ORDER BY student_person_id, course_id;
-- Expected: (1,ENPM605), (1,ENPM818T), (2,ENPM818T), (4,ENPM702), (5,ENPM818T)
-- David(4) is only in ENPM702 now.

-- SAVEPOINT demo
-- The three initial inserts all use combos that do NOT exist yet:
--   Bob(2)   + ENPM702/0101  -- Bob only in ENPM818T
--   David(4) + ENPM818T/0101 -- David only in ENPM702
--   Eve(5)   + ENPM702/0101  -- Eve only in ENPM818T
BEGIN;
    INSERT INTO enrollment VALUES (2, 'ENPM702', '0101', NULL);
    INSERT INTO enrollment VALUES (4, 'ENPM818T', '0101', NULL);
    INSERT INTO enrollment VALUES (5, 'ENPM702', '0101', NULL);

    SAVEPOINT after_three;

    INSERT INTO enrollment VALUES (4, 'ENPM818T', '0101', NULL);
    -- FAIL: duplicate PK -- David(4)/ENPM818T/0101 was just inserted above

    ROLLBACK TO SAVEPOINT after_three;
    -- Rows for (2/ENPM702), (4/ENPM818T), (5/ENPM702) still live.
    -- Failed insert is gone.

    -- Replace the failed row with a valid one
    INSERT INTO enrollment VALUES (2, 'ENPM605', '0101', NULL);
    -- Bob(2) in ENPM605 -- does not conflict
COMMIT;
-- 4 rows committed: (2/ENPM702), (4/ENPM818T), (5/ENPM702), (2/ENPM605)

-- Verify exactly the expected rows exist
SELECT student_person_id, course_id, section_no
FROM enrollment
ORDER BY student_person_id, course_id;

-- State after Demo 8:
--   New enrollments: (2,ENPM702), (4,ENPM818T), (5,ENPM702), (2,ENPM605)
--   Total enrollment rows: 9
--   ENPM818T/0101 capacity = 30 (untouched by SAVEPOINT demo)


-- ============================================================
-- Demo 9 (psycopg3): Minimal connection
-- Slide: demostep{8}
-- Run extra/standalone_test.py -- no SQL state change here.
-- Verify from psql after running the Python script:
-- ============================================================

SELECT count(*) AS active_connections
FROM pg_stat_activity
WHERE datname = 'university_db';


-- ============================================================
-- Demo 10 (psycopg3): conn.transaction() -- atomic enrollment
-- Slide: demostep{9}
-- Uses person_id=5 (Eve) who is NOT yet enrolled in ENPM702.
-- Run extra/demo_transaction.py -- verify here after.
-- State entering: ENPM818T/0101 capacity=30
--                 Eve(5) NOT in ENPM702/0101
-- ============================================================

-- Pre-check
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 30

-- After running extra/demo_transaction.py with person_id=5, ENPM818T, 0101:
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29 (successful enrollment committed)

SELECT student_person_id, course_id, section_no
FROM enrollment
WHERE student_person_id = 5 AND course_id = 'ENPM818T';
-- Expected: the enrollment row for Eve (already existed from seed -- 
-- the Python demo should use a section Eve is NOT in, e.g. ENPM702/0101)

-- NOTE FOR INSTRUCTOR: the Python demo script should use:
--   person_id=5 (Eve), course_id='ENPM702', section_no='0101'
-- Eve is NOT enrolled in ENPM702 so the demo succeeds cleanly.

-- For the ROLLBACK path (person_id=999):
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM702' AND section_no = '0101';
-- Capacity should be unchanged (ROLLBACK restored it)


-- ============================================================
-- Demo 11 (psycopg3): EnrollmentService
-- Slide: demostep{10}
-- Run extra/demo_enrollment_service.py
-- Set capacity to 2 to exhaust the section quickly.
-- ============================================================

-- Set capacity to 2 before running the Python script
UPDATE course_section SET capacity = 2
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- After running demo_enrollment_service.py (two successful enrollments):
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 0

-- Third call should raise ValueError("Section is full") -- no row inserted.
SELECT count(*) FROM enrollment
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- Reset capacity after demo
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- RESTRICT demo (slides: ON DELETE RESTRICT schema + error slides)
-- These slides do NOT have a demostep{} counter but are shown live.
-- Run after Demo 5 (Exercise 1) or as a standalone block.
-- ENPM605 appears as both prereq_id (ENPM818T requires it) and
-- successor_id (ENPM605 requires ENPM601) -- both RESTRICT FKs fire.
-- ============================================================

-- Attempt: blocked by RESTRICT
DELETE FROM course WHERE course_id = 'ENPM605';
-- ERROR: violates foreign key constraint "fk_cp_prereq"
-- DETAIL: Key (course_id)=(ENPM605) is still referenced

-- Fix: remove all course_prereq rows that mention ENPM605 on either side
DELETE FROM course_prereq
    WHERE prereq_id    = 'ENPM605'
       OR successor_id = 'ENPM605';

-- Now the parent row is unreferenced
DELETE FROM course WHERE course_id = 'ENPM605';
-- Succeeds

-- Restore ENPM605 for subsequent demos
INSERT INTO course VALUES ('ENPM605', 1, 'Python for Robotics', 3);
INSERT INTO course_prereq VALUES ('ENPM605',  'ENPM601');
INSERT INTO course_prereq VALUES ('ENPM818T', 'ENPM605');
INSERT INTO course_section VALUES ('ENPM605', '0101', 30)
    ON CONFLICT DO NOTHING;


-- ============================================================
-- UPDATE ... FROM demo (slide has no demostep counter)
-- Run after Demo 3b.
-- ============================================================

-- Populate the mapping table
INSERT INTO dept_mapping (person_id, dept_id) VALUES (3, 2), (7, 1);

-- Temporarily clear dept_id so the demo is visible
UPDATE professor SET dept_id = NULL WHERE person_id IN (3, 7);

-- UPDATE ... FROM
UPDATE professor p
    SET dept_id = m.dept_id
    FROM dept_mapping m
    WHERE m.person_id = p.person_id
      AND p.dept_id IS NULL
    RETURNING p.person_id, p.dept_id AS new_dept;

-- Restore original dept assignments and clean mapping table
UPDATE professor SET dept_id = 1 WHERE person_id = 3;
UPDATE professor SET dept_id = 1 WHERE person_id = 7;
DELETE FROM dept_mapping;


-- ============================================================
-- Isolation anomaly demos (slides have no demostep counter)
-- These all require TWO open connections in DataGrip.
-- Run each CONNECTION block in a separate DataGrip SQL console.
-- ============================================================

-- ANOMALY 1: Dirty Read -- CANNOT be reproduced in PostgreSQL.
-- Show the code and explain; do not run.

-- ANOMALY 2: Non-Repeatable Read under READ COMMITTED
-- CONNECTION 1 (Session A):
BEGIN;
SELECT gpa FROM student WHERE person_id = 1;
-- Returns 3.75

-- While Session A is open, run in CONNECTION 2 (Session B) -- autocommit:
-- UPDATE student SET gpa = 2.0 WHERE person_id = 1;

-- Back in SESSION A:
SELECT gpa FROM student WHERE person_id = 1;
-- Under READ COMMITTED: returns 2.0
COMMIT;

-- Restore
UPDATE student SET gpa = 3.75 WHERE person_id = 1;

-- ANOMALY 2 PREVENTED: Repeatable Read
-- CONNECTION 1 (Session A):
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT gpa FROM student WHERE person_id = 1;
-- Returns 3.75

-- While Session A is open, run in CONNECTION 2 (Session B) -- autocommit:
-- UPDATE student SET gpa = 2.0 WHERE person_id = 1;

-- Back in SESSION A:
SELECT gpa FROM student WHERE person_id = 1;
-- Under REPEATABLE READ: still returns 3.75
COMMIT;

-- Restore
UPDATE student SET gpa = 3.75 WHERE person_id = 1;

-- ANOMALY 3: Phantom Read under READ COMMITTED
-- CONNECTION 1 (Session A):
BEGIN;
SELECT count(*) FROM student WHERE gpa > 3.5;
-- Returns 2 (Alice=3.75, David=3.20 -- wait, only Alice > 3.5)
-- Actually: Alice(1)=3.75 only. David(4)=3.20, Bob(2)=1.85, Eve(5)=1.92
-- Returns 1.

-- While Session A is open, run in CONNECTION 2 (Session B) -- autocommit:
-- INSERT INTO person (first_name, last_name, date_of_birth)
--     VALUES ('New', 'Student', '2001-01-01') RETURNING person_id;
-- INSERT INTO student VALUES (<returned_id>, '117999999', '2025-08-25',
--     'Good Standing', 3.90);

-- Back in SESSION A:
SELECT count(*) FROM student WHERE gpa > 3.5;
-- Under READ COMMITTED: returns 2 (phantom row appeared)
COMMIT;

-- ANOMALY 4: Write Skew -- requires SERIALIZABLE to prevent
SELECT * FROM on_call;
-- Shows A and B

-- CONNECTION 1 (Session A):
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT count(*) FROM on_call; -- Returns 2, safe to remove one
-- (pause -- do NOT commit yet)

-- CONNECTION 2 (Session B):
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT count(*) FROM on_call; -- Returns 2, safe to remove one
-- DELETE FROM on_call WHERE doctor = 'B';
-- COMMIT;

-- Back in SESSION A:
-- DELETE FROM on_call WHERE doctor = 'A';
-- COMMIT;
-- SELECT * FROM on_call; -- 0 rows -- constraint violated

-- Restore on_call
INSERT INTO on_call VALUES ('A'), ('B') ON CONFLICT DO NOTHING;

-- FOR UPDATE demo (SELECT ... FOR UPDATE slide, no demostep)
-- Run in CONNECTION 1 only (show the lock; Session B blocked):
UPDATE course_section SET capacity = 1
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

BEGIN;
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101'
    FOR UPDATE;
-- Session A holds the row lock; Session B blocks here if it tries the same SELECT FOR UPDATE

UPDATE course_section
    SET capacity = capacity - 1
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
INSERT INTO enrollment (student_person_id, course_id, section_no)
    VALUES (4, 'ENPM818T', '0101')
    ON CONFLICT DO NOTHING;
COMMIT;

-- Reset
DELETE FROM enrollment
    WHERE student_person_id = 4
      AND course_id = 'ENPM818T'
      AND grade IS NULL;
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- Full reset: restore database to clean seed state
-- Run this at the end of a lecture session to reset for next time.
-- ============================================================
UPDATE course_section SET capacity = 30;
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing != 'Good Standing';
UPDATE student SET gpa = 3.75 WHERE person_id = 1;
UPDATE course SET title = 'Data Storage and Databases'
    WHERE course_id = 'ENPM818T';
DELETE FROM enrollment
    WHERE (student_person_id, course_id, section_no) NOT IN (
        VALUES (1,'ENPM818T','0101'),
               (2,'ENPM818T','0101'),
               (1,'ENPM605', '0101'),
               (4,'ENPM702', '0101'),
               (5,'ENPM818T','0101')
    );
DELETE FROM professor WHERE person_id NOT IN (3,6,7,8,9);
DELETE FROM student    WHERE person_id NOT IN (1,2,4,5);
DELETE FROM person     WHERE person_id NOT IN (1,2,3,4,5,6,7,8,9,10);
UPDATE professor SET dept_id = 1 WHERE person_id IN (3, 7);
UPDATE professor SET dept_id = 2 WHERE person_id = 6;
UPDATE professor SET dept_id = 3 WHERE person_id = 8;
UPDATE professor SET dept_id = 4 WHERE person_id = 9;
UPDATE professor SET rank_code = 'Associate' WHERE person_id IN (3, 7, 9);
UPDATE professor SET rank_code = 'Full'      WHERE person_id = 6;
UPDATE professor SET rank_code = 'Assistant' WHERE person_id = 8;
DELETE FROM dept_mapping;
TRUNCATE honors_student, student_archive;
INSERT INTO on_call VALUES ('A'), ('B') ON CONFLICT DO NOTHING;
-- Restore Zara in person (not student) for subsequent use
INSERT INTO person (first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14')
    ON CONFLICT DO NOTHING;

-- Final verification
SELECT 'person'     AS tbl, count(*) FROM person
UNION ALL SELECT 'student',    count(*) FROM student
UNION ALL SELECT 'enrollment', count(*) FROM enrollment
UNION ALL SELECT 'course',     count(*) FROM course
UNION ALL SELECT 'course_prereq', count(*) FROM course_prereq;
-- Expected: person=10, student=4, enrollment=5, course=4, course_prereq=2
