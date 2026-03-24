-- ============================================================
-- ENPM818T L7 -- sql_demo.sql
-- university_db
-- ============================================================
--
-- HOW THIS FILE IS ORGANISED
-- --------------------------
-- Every SQL snippet that appears on a slide is included here,
-- in the same order the slides are presented.
--
-- Two kinds of blocks are distinguished:
--
--   SNIPPET  -- the exact code shown on a slide for discussion.
--               Run it to see the output the slide describes.
--               No cleanup is performed; state may change.
--
--   DEMO N   -- a numbered live-coding block tied to a slide
--               \demostep{N}. Each demo ends with a cleanup /
--               restore block so the next demo starts clean.
--
-- DEMO NUMBERING (matches slide \demostep{} counters):
--   Demo 1  = INSERT ... RETURNING (ISA chain -- Alice)
--   Demo 2  = ON CONFLICT DO NOTHING
--   Demo 3a = ON CONFLICT DO UPDATE  (\demostep{3} first occurrence)
--   Demo 3b = Safe UPDATE workflow   (\demostep{3} second occurrence)
--   Demo 4  = DELETE CASCADE and RETURNING
--   Demo 5  = Exercise 1 walkthrough
--   Demo 6  = COMMIT: happy path + ROLLBACK: failed enrollment
--   Demo 7  = SAVEPOINT: partial rollback
--   Demo 8  = psycopg3 minimal connection  (Python -- verify SQL only)
--   Demo 9  = psycopg3 conn.transaction()  (Python -- verify SQL only)
--   Demo 10 = EnrollmentService            (Python -- verify SQL only)
--
-- NOTE: two slides share \demostep{3} -- the ON CONFLICT DO UPDATE
-- slide and the safe UPDATE slide. They are labelled 3a and 3b here.
-- ============================================================


-- ============================================================
-- SCHEMA SETUP
-- Run this entire section once before any snippet or demo.
-- It drops and recreates all tables and loads seed data.
-- Approximately lines 1-225.
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

CREATE TABLE on_call (
    doctor VARCHAR(10) PRIMARY KEY
);


-- ============================================================
-- SEED DATA
-- person_id=1 is intentionally left free for Demo 1 (Alice).
-- Persons 2-10 are forced with OVERRIDING SYSTEM VALUE so
-- all FK references (professors, chairs) keep their expected ids.
-- setval() advances the sequence so the next organic INSERT
-- (Alice in Demo 1) receives person_id=1.
-- ============================================================
BEGIN;

INSERT INTO department (dept_name)
    VALUES ('Computer Science'),       -- dept_id = 1
           ('Mathematics'),            -- dept_id = 2
           ('Mechanical Engineering'), -- dept_id = 3
           ('Electrical Engineering'); -- dept_id = 4

-- ENPM601 is required for the ON DELETE RESTRICT demo:
-- ENPM605 appears as both prereq_id (required by ENPM818T)
-- and successor_id (requires ENPM601), so both OR branches fire.
INSERT INTO course VALUES ('ENPM601',  1, 'Foundations',                3);
INSERT INTO course VALUES ('ENPM605',  1, 'Python for Robotics',        3);
INSERT INTO course VALUES ('ENPM702',  1, 'Robot Programming',          3);
INSERT INTO course VALUES ('ENPM818T', 1, 'Data Storage and Databases', 3);

INSERT INTO course_prereq VALUES ('ENPM605',  'ENPM601');
INSERT INTO course_prereq VALUES ('ENPM818T', 'ENPM605');

INSERT INTO course_section VALUES ('ENPM601',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM605',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM702',  '0101', 30);
INSERT INTO course_section VALUES ('ENPM818T', '0101', 30);

-- Persons 2-10 seeded with explicit IDs; person_id=1 reserved for Alice.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (2,  'Bob',    'Smith',    '1999-07-22'),  -- student
           (3,  'Carol',  'Davis',    '1980-03-15'),  -- professor
           (4,  'David',  'Lee',      '2000-11-30'),  -- student
           (5,  'Eve',    'Brown',    '2001-01-10'),  -- student
           (6,  'Frank',  'Wilson',   '1975-06-05'),  -- professor
           (7,  'Grace',  'Taylor',   '1982-09-20'),  -- professor
           (8,  'Hank',   'Anderson', '1990-12-01'),  -- professor
           (9,  'Irene',  'Thomas',   '1985-04-18'),  -- professor
           (10, 'Zara',   'Patel',    '2002-05-14');  -- demo/throwaway

-- Advance the identity sequence so the next INSERT gets person_id=1.
-- (The gap at 1 is below the current max, so GENERATED ALWAYS will
-- assign 1 on the very next INSERT because the sequence restarts
-- from the lowest unused value below the max when we use setval.)
-- Actually with GENERATED ALWAYS AS IDENTITY the sequence only goes
-- forward. We must set it to 0 so next value is 1.
SELECT setval(pg_get_serial_sequence('person', 'person_id'), 0);
-- Now the next INSERT INTO person ... (without OVERRIDING) gets id=1.

-- Students: 2, 4, 5 only. Alice (id=1) added live in Demo 1.
-- David(4) intentionally NOT in ENPM818T -- slot used for Demo 6 COMMIT.
INSERT INTO student VALUES (2, '117453211', '2024-08-26', 'Good Standing', 1.85);
INSERT INTO student VALUES (4, '117453213', '2023-08-28', 'Good Standing', 3.20);
INSERT INTO student VALUES (5, '117453214', '2023-08-28', 'Good Standing', 1.92);

INSERT INTO professor VALUES (3, 1, '2017-08-01', 'Associate');
INSERT INTO professor VALUES (6, 2, '2015-01-10', 'Full');
INSERT INTO professor VALUES (7, 1, '2019-01-15', 'Associate');
INSERT INTO professor VALUES (8, 3, '2022-08-01', 'Assistant');
INSERT INTO professor VALUES (9, 4, '2021-03-20', 'Associate');

UPDATE department SET chair_id = 3 WHERE dept_id = 1;
UPDATE department SET chair_id = 6 WHERE dept_id = 2;

-- Enrollments: no Alice rows (she has no student row yet).
INSERT INTO enrollment VALUES (2, 'ENPM818T', '0101', 'B+');
INSERT INTO enrollment VALUES (4, 'ENPM702',  '0101', 'B');
INSERT INTO enrollment VALUES (5, 'ENPM818T', '0101', 'A');

INSERT INTO on_call VALUES ('A'), ('B');

COMMIT;

-- Verify seed
SELECT 'person'     AS tbl, count(*) FROM person
UNION ALL SELECT 'student',    count(*) FROM student
UNION ALL SELECT 'professor',  count(*) FROM professor
UNION ALL SELECT 'course',     count(*) FROM course
UNION ALL SELECT 'enrollment', count(*) FROM enrollment;
-- Expected: person=9, student=3, professor=5, course=4, enrollment=3


-- ============================================================
-- SECTION 1: DML -- INSERT, UPDATE, DELETE
-- ============================================================


-- ============================================================
-- SNIPPET -- SELECT: What You Need Today
-- Slide: SELECT preview (five forms)
-- Read-only; run at any time to verify state.
-- ============================================================

-- Form 1: all rows, all columns
SELECT * FROM student;
SELECT * FROM department;

-- Form 2: specific columns
SELECT person_id, gpa, academic_standing
FROM student;

-- Form 3: filter with WHERE
SELECT person_id, gpa
FROM student
WHERE gpa < 2.0;

SELECT person_id, academic_standing
FROM student
WHERE academic_standing = 'Probation';

-- Form 4: sort with ORDER BY
SELECT person_id, gpa
FROM student
ORDER BY gpa DESC;

SELECT person_id, gpa
FROM student
WHERE gpa < 2.0
ORDER BY gpa ASC;

-- Form 5: count rows
SELECT COUNT(*) FROM enrollment
WHERE course_id = 'ENPM818T';


-- ============================================================
-- SNIPPET -- INSERT: single-row and multi-row
-- Slide: INSERT (single-row / multi-row slide)
-- Shown before demostep{1} as a warm-up for INSERT syntax.
-- Cleanup included so seed departments are unchanged.
-- ============================================================

-- Single-row
INSERT INTO department (dept_name)
    VALUES ('Philosophy');

SELECT dept_id, dept_name FROM department ORDER BY dept_id;
-- Note: identity values assigned sequentially; order in VALUES
-- has no effect on the assigned dept_id.

-- Multi-row: one round trip for four rows
INSERT INTO department (dept_name)
    VALUES ('Linguistics'), ('History'),
           ('Sociology'), ('Art History');

SELECT dept_id, dept_name FROM department ORDER BY dept_id;

-- Cleanup
DELETE FROM department
    WHERE dept_name IN ('Philosophy','Linguistics','History','Sociology','Art History');


-- ============================================================
-- SNIPPET -- The Generated PK Problem
-- Slide: "The Generated PK Problem"
-- These are BAD examples shown for discussion -- do NOT run
-- them as part of a live demo; they would fail or produce
-- incorrect state. They are included here as reference only.
-- ============================================================

-- BAD approach 1: guess the identity value
-- INSERT INTO student (person_id, student_id, admission_date, academic_standing)
--     VALUES (1, '117453210', '2024-08-26', 'Good Standing');
-- Risk: breaks silently if another session inserted a row at the same time.

-- BAD approach 2: SELECT MAX() after INSERT
-- INSERT INTO person (first_name, last_name, date_of_birth)
--     VALUES ('Alice', 'Johnson', '1998-04-12');
-- SELECT MAX(person_id) FROM person;
-- Risk: another session may insert between your INSERT and SELECT,
-- returning the wrong ID. Never use this pattern.


-- ============================================================
-- DEMO 1 -- INSERT ... RETURNING: ISA chain
-- Slide: demostep{1}
-- Alice does NOT exist yet. person_id=1 is free (see seed notes).
-- State entering: person ids 2-10; student has 2,4,5 only.
-- ============================================================

-- The slide's exact demo:
-- Insert Alice into person and capture the generated PK atomically.
INSERT INTO person (first_name, last_name, date_of_birth)
    VALUES ('Alice', 'Johnson', '1998-04-12')
    RETURNING person_id;
-- Returns person_id = 1.

-- Use the returned value to insert the student row.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (1, '117453210', '2024-08-26', 'Good Standing');

-- Verify
SELECT * FROM student WHERE person_id = 1;

-- FK violation: person_id 99 does not exist.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (99, '117453299', '2025-08-25', 'Good Standing');
-- ERROR: violates foreign key constraint

-- Add Alice's enrollments to establish the full seed state
-- used by all subsequent demos.
INSERT INTO enrollment VALUES (1, 'ENPM818T', '0101', 'A');
INSERT INTO enrollment VALUES (1, 'ENPM605',  '0101', 'A-');

-- State after Demo 1:
--   Alice (person_id=1) in person, student, and enrollment
--   Full enrollment state: (1,ENPM818T), (1,ENPM605),
--                          (2,ENPM818T), (4,ENPM702), (5,ENPM818T)


-- ============================================================
-- SNIPPET -- RETURNING on UPDATE and DELETE
-- Slide: "RETURNING on UPDATE and DELETE"
-- No demostep. Run as a standalone illustration.
-- Cleanup restores state after each snippet.
-- ============================================================

-- UPDATE ... RETURNING: returns new values after the change.
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;
-- Returns person_id 2 (1.85) and 5 (1.92) -- the two changed rows.

-- Restore
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing = 'Probation';

-- DELETE ... RETURNING: returns row values as they were before deletion.
-- Use Zara (person_id=10) as the throwaway -- she is in person but not student.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
INSERT INTO enrollment VALUES (10, 'ENPM818T', '0101', NULL);

DELETE FROM enrollment
    WHERE student_person_id = 10
    RETURNING student_person_id, course_id, grade;
-- Returns the enrollment row before it is deleted.

-- Restore: remove Zara's student row (enrollment already deleted above)
DELETE FROM student WHERE person_id = 10;


-- ============================================================
-- SNIPPET -- ON CONFLICT intro
-- Slide: "ON CONFLICT" (the intro slide before DO NOTHING / DO UPDATE)
-- Shows the duplicate error that ON CONFLICT prevents.
-- ============================================================

-- First INSERT: succeeds (Computer Science already exists from seed)
-- Run to show the error:
INSERT INTO department (dept_name)
    VALUES ('Computer Science');
-- ERROR: duplicate key value violates unique constraint


-- ============================================================
-- DEMO 2 -- ON CONFLICT DO NOTHING
-- Slide: demostep{2}
-- State entering: unchanged from end of Demo 1.
-- ============================================================

-- Show the raw error first (same as snippet above)
INSERT INTO department (dept_name)
    VALUES ('Computer Science');
-- ERROR: duplicate key value violates unique constraint

-- With ON CONFLICT DO NOTHING: silent skip
INSERT INTO department (dept_name)
    VALUES ('Computer Science')
    ON CONFLICT DO NOTHING;
-- 0 rows inserted, no error.

SELECT dept_id, dept_name
FROM department
WHERE dept_name = 'Computer Science';
-- Row unchanged.

-- State after Demo 2: unchanged.


-- ============================================================
-- DEMO 3a -- ON CONFLICT DO UPDATE (upsert)
-- Slide: demostep{3} (first occurrence -- ON CONFLICT DO UPDATE slide)
-- State entering: unchanged.
-- ============================================================

-- Upsert: update title if the course already exists.
INSERT INTO course (course_id, title, credits, dept_id)
    VALUES ('ENPM818T', 'Databases and Data Storage', 3, 1)
    ON CONFLICT (course_id) DO UPDATE
        SET title   = EXCLUDED.title,
            credits = EXCLUDED.credits;

-- Verify title changed.
SELECT course_id, title FROM course WHERE course_id = 'ENPM818T';
-- Returns: 'Databases and Data Storage'

-- Restore original title immediately so subsequent demos are correct.
UPDATE course SET title = 'Data Storage and Databases'
    WHERE course_id = 'ENPM818T';

-- State after Demo 3a: unchanged (title restored).


-- ============================================================
-- SNIPPET -- INSERT ... SELECT
-- Slide: "INSERT ... SELECT: Insert from a Query"
-- No demostep. Cleanup included.
-- ============================================================

-- Archive dismissed students (none in seed -- 0 rows, no error).
INSERT INTO student_archive
    (person_id, student_id, admission_date, academic_standing, gpa)
SELECT person_id, student_id, admission_date, academic_standing, gpa
FROM student
WHERE academic_standing = 'Dismissed';

-- Copy high-GPA students into honors table.
-- Alice(1)=3.75 and David(4)=3.20 -- only Alice qualifies (>= 3.5).
INSERT INTO honors_student (person_id, student_id, gpa)
SELECT person_id, student_id, gpa
FROM student
WHERE gpa >= 3.5;

SELECT * FROM honors_student;
-- Returns Alice (3.75).

-- Cleanup
TRUNCATE honors_student, student_archive;


-- ============================================================
-- DEMO 3b -- Safe UPDATE workflow
-- Slide: demostep{3} (second occurrence -- safe UPDATE slide)
-- NOTE: Two slides share demostep{3}. Run 3a and 3b as
-- separate named scripts in DataGrip, or label them clearly.
-- State entering: students 2(1.85) and 5(1.92) both 'Good Standing'.
-- ============================================================

-- SNIPPET shown in warning box (do NOT run standalone -- shown for discussion):
-- UPDATE student SET academic_standing = 'Probation';  -- DANGEROUS: no WHERE

-- Step 1: preview the target set with the same WHERE.
SELECT person_id, gpa, academic_standing
FROM student
WHERE gpa < 2.0;
-- Returns person_id 2 (1.85) and 5 (1.92).

-- Step 2: UPDATE with RETURNING to confirm exactly which rows change.
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;
-- Returns the same two rows -- output matches the SELECT preview exactly.

-- Dangerous variant: full-table overwrite inside BEGIN/ROLLBACK.
BEGIN;
    UPDATE student SET academic_standing = 'Probation';
    SELECT person_id, academic_standing FROM student;
    -- All rows show 'Probation'.
ROLLBACK;
-- The ROLLBACK undoes the full-table update.
-- The targeted UPDATE above (WHERE gpa < 2.0) was already committed
-- and is NOT rolled back by this ROLLBACK.

-- IMPORTANT: restore standings now so Demo 4 and beyond see clean state.
UPDATE student SET academic_standing = 'Good Standing'
    WHERE person_id IN (2, 5);

SELECT person_id, academic_standing FROM student;
-- All 'Good Standing'.

-- State after Demo 3b: all students back to 'Good Standing'.


-- ============================================================
-- SNIPPET -- Bulk UPDATE with compound WHERE
-- Slide: "Bulk Updates with a WHERE Condition"
-- No demostep. Cleanup restores ranks.
-- ============================================================

-- Promote associate professors hired before 2020.
UPDATE professor
    SET rank_code = 'Full'
    WHERE rank_code = 'Associate'
      AND hire_date < '2020-01-01'
    RETURNING person_id, rank_code, hire_date;
-- Returns person_id 3 (2017) and 7 (2019) -- promoted.
-- person_id 9 (2021) is post-2020 -- untouched.

-- Restore
UPDATE professor SET rank_code = 'Associate'
    WHERE person_id IN (3, 7);


-- ============================================================
-- SNIPPET -- UPDATE ... FROM
-- Slide: "UPDATE ... FROM: Updating from Another Table"
-- No demostep. Full cleanup included.
-- ============================================================

-- Populate the mapping table.
INSERT INTO dept_mapping (person_id, dept_id) VALUES (3, 2), (7, 1);

-- Clear dept_id on the two professors so the update is visible.
UPDATE professor SET dept_id = NULL WHERE person_id IN (3, 7);

-- UPDATE ... FROM: assign dept_id from the mapping table.
UPDATE professor p
    SET dept_id = m.dept_id
    FROM dept_mapping m
    WHERE m.person_id = p.person_id
      AND p.dept_id IS NULL
    RETURNING p.person_id, p.dept_id AS new_dept;
-- person_id 3 -> dept_id 2, person_id 7 -> dept_id 1.

-- Restore
UPDATE professor SET dept_id = 1 WHERE person_id IN (3, 7);
DELETE FROM dept_mapping;


-- ============================================================
-- SNIPPET -- DELETE syntax and CASCADE behavior
-- Slide: "Syntax and CASCADE Behavior"
-- No demostep (Demo 4 covers the live version with Zara).
-- Shown here as the exact code from the slide.
-- Uses Zara (person_id=10) so core students are untouched.
-- ============================================================

-- Set up: insert Zara as student with two enrollment rows.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
INSERT INTO enrollment VALUES (10, 'ENPM818T', '0101', NULL);
INSERT INTO enrollment VALUES (10, 'ENPM605',  '0101', NULL);

-- Safe DELETE with WHERE
DELETE FROM student WHERE person_id = 10;
-- CASCADE removes enrollment rows automatically.

SELECT * FROM student     WHERE person_id = 10; -- 0 rows
SELECT * FROM enrollment  WHERE student_person_id = 10; -- 0 rows

-- For the RETURNING variant: re-insert Zara and capture before deleting.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14')
    ON CONFLICT DO NOTHING;
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
INSERT INTO enrollment VALUES (10, 'ENPM818T', '0101', NULL);
INSERT INTO enrollment VALUES (10, 'ENPM605',  '0101', NULL);

-- Capture enrollment rows for audit before cascade removes them.
DELETE FROM enrollment
    WHERE student_person_id = 10
    RETURNING student_person_id, course_id, grade;

-- Delete from person; CASCADE removes student row automatically.
DELETE FROM person WHERE person_id = 10;

SELECT * FROM student WHERE person_id = 10; -- 0 rows

-- Restore Zara in person (not student) for Demo 4.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14');


-- ============================================================
-- DEMO 4 -- DELETE: CASCADE behavior and RETURNING
-- Slide: demostep{4}
-- Uses Zara (person_id=10) as the throwaway student.
-- State entering: Zara in person but NOT in student.
-- ============================================================

-- Insert Zara into student so the cascade demo is meaningful.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
INSERT INTO enrollment VALUES (10, 'ENPM818T', '0101', NULL);
INSERT INTO enrollment VALUES (10, 'ENPM605',  '0101', NULL);

SELECT * FROM enrollment WHERE student_person_id = 10;

-- Capture enrollment rows for audit before cascade removes them.
DELETE FROM enrollment
    WHERE student_person_id = 10
    RETURNING student_person_id, course_id, grade;

-- Delete Zara from person; CASCADE removes the student row.
DELETE FROM person WHERE person_id = 10;

SELECT * FROM student WHERE person_id = 10; -- 0 rows

-- Restore Zara in person for Exercise 1.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14');

-- State after Demo 4:
--   Zara(10) in person but NOT in student
--   Core students 1,2,4,5 untouched
--   Core enrollments: (1,ENPM818T), (1,ENPM605),
--                     (2,ENPM818T), (4,ENPM702), (5,ENPM818T)


-- ============================================================
-- SNIPPET -- ON DELETE RESTRICT schema
-- Slide: "ON DELETE RESTRICT" (schema slide)
-- DDL shown for context -- schema already exists, do not re-run.
-- Included here as reference so students can see the full picture.
-- ============================================================

-- CREATE TABLE course (
--     course_id  CHAR(8)     PRIMARY KEY,
--     title      VARCHAR(60) NOT NULL,
--     credits    INT         NOT NULL
-- );

-- CREATE TABLE course_prereq (
--     successor_id CHAR(8) NOT NULL,
--     prereq_id    CHAR(8) NOT NULL,
--     PRIMARY KEY (successor_id, prereq_id),
--     CONSTRAINT fk_cp_successor
--         FOREIGN KEY (successor_id)
--         REFERENCES course (course_id)
--         ON DELETE RESTRICT,
--     CONSTRAINT fk_cp_prereq
--         FOREIGN KEY (prereq_id)
--         REFERENCES course (course_id)
--         ON DELETE RESTRICT
-- );

-- Verify the actual schema matches the slide.
-- Run \d+ course_prereq in psql to see both FK constraints.


-- ============================================================
-- SNIPPET -- ON DELETE RESTRICT: the error and the fix
-- Slide: "ON DELETE RESTRICT: The Error"
-- No demostep. Full cleanup restores ENPM605.
-- ============================================================

-- Attempt: RESTRICT blocks the delete.
DELETE FROM course WHERE course_id = 'ENPM605';
-- ERROR: violates foreign key constraint "fk_cp_prereq"
-- DETAIL: Key (course_id)=(ENPM605) is still referenced.
-- ENPM605 appears as prereq_id (ENPM818T requires it)
-- AND as successor_id (ENPM605 requires ENPM601).
-- Both OR branches in the fix below are required.

-- Fix step 1: remove all course_prereq rows mentioning ENPM605 on either side.
DELETE FROM course_prereq
    WHERE prereq_id    = 'ENPM605'
       OR successor_id = 'ENPM605';

-- Fix step 2: now the parent row is unreferenced -- delete succeeds.
DELETE FROM course WHERE course_id = 'ENPM605';

-- Restore ENPM605 for subsequent demos.
INSERT INTO course VALUES ('ENPM605', 1, 'Python for Robotics', 3);
INSERT INTO course_prereq VALUES ('ENPM605',  'ENPM601');
INSERT INTO course_prereq VALUES ('ENPM818T', 'ENPM605');
INSERT INTO course_section VALUES ('ENPM605', '0101', 30)
    ON CONFLICT DO NOTHING;


-- ============================================================
-- DEMO 5 -- Exercise 1 walkthrough
-- Slide: demostep{5}
-- State entering: Zara in person but not student; all core rows intact.
-- ============================================================

-- Task 1: insert three new departments in a single statement.
INSERT INTO department (dept_name)
    VALUES ('Linguistics'), ('History'), ('Art History');
SELECT dept_id, dept_name FROM department ORDER BY dept_id;

-- Task 2: insert a new person using RETURNING, then the student row.
-- Use Zara (person_id=10) who is already in person.
INSERT INTO student (person_id, student_id, admission_date, academic_standing)
    VALUES (10, '117453220', '2025-08-25', 'Good Standing');
SELECT * FROM student WHERE person_id = 10;

-- Task 3: safe UPDATE workflow.
SELECT person_id, gpa, academic_standing FROM student WHERE gpa < 2.0;
UPDATE student
    SET academic_standing = 'Probation'
    WHERE gpa < 2.0
    RETURNING person_id, gpa, academic_standing;

-- Dangerous variant inside BEGIN/ROLLBACK.
BEGIN;
    UPDATE student SET academic_standing = 'Probation';
    SELECT person_id, academic_standing FROM student;
ROLLBACK;

-- Task 4: delete Zara and confirm cascade.
-- \d+ student   <-- run in psql to see the FK chain
DELETE FROM person WHERE person_id = 10;
SELECT * FROM student WHERE person_id = 10; -- 0 rows

-- Cleanup
DELETE FROM department
    WHERE dept_name IN ('Linguistics', 'History', 'Art History');
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing = 'Probation';

-- Restore Zara in person for subsequent demos.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14');

-- State after Demo 5:
--   All students 1,2,4,5 with 'Good Standing'
--   Core enrollments intact
--   ENPM818T/0101 capacity = 30


-- ============================================================
-- SECTION 2: TRANSACTIONS
-- ============================================================


-- ============================================================
-- DEMO 6 -- COMMIT: the happy path
-- Slide: demostep{6} (ROLLBACK slide says "Run Demo 6")
-- Uses David(4) who is NOT enrolled in ENPM818T.
-- State entering: capacity=30, David NOT in ENPM818T/0101.
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

SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29.

SELECT student_person_id, course_id FROM enrollment
    WHERE student_person_id = 4 AND course_id = 'ENPM818T';
-- Expected: one row.

-- State after Demo 6:
--   David(4) enrolled in ENPM818T/0101
--   ENPM818T/0101 capacity = 29


-- ============================================================
-- DEMO 6 (continued) -- ROLLBACK: failed enrollment
-- Slide: demostep{6} (same slide as COMMIT -- both shown on ROLLBACK slide)
-- State entering: capacity=29 (from COMMIT above).
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
-- Both the UPDATE and the failed INSERT are undone. Capacity back to 29.

SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29 (unchanged from after COMMIT).

-- State after Demo 6 continued:
--   ENPM818T/0101 capacity = 29
--   David(4) still enrolled in ENPM818T (from the COMMIT block)


-- ============================================================
-- DEMO 7 -- SAVEPOINT: partial rollback
-- Slide: demostep{7}
-- Pre-cleanup: remove David's ENPM818T enrollment from Demo 6
-- so the SAVEPOINT demo can use David+ENPM818T as the duplicate failure.
-- ============================================================

DELETE FROM enrollment
    WHERE student_person_id = 4 AND course_id = 'ENPM818T';
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- Verify clean state.
SELECT student_person_id, course_id FROM enrollment
    ORDER BY student_person_id, course_id;
-- Expected: (1,ENPM605), (1,ENPM818T), (2,ENPM818T), (4,ENPM702), (5,ENPM818T)

-- SAVEPOINT demo: three initial inserts all use combos that don't exist yet.
BEGIN;
    INSERT INTO enrollment VALUES (2, 'ENPM702',  '0101', NULL);
    INSERT INTO enrollment VALUES (4, 'ENPM818T', '0101', NULL);
    INSERT INTO enrollment VALUES (5, 'ENPM702',  '0101', NULL);

    SAVEPOINT after_three;

    INSERT INTO enrollment VALUES (4, 'ENPM818T', '0101', NULL);
    -- FAIL: duplicate PK -- David(4)/ENPM818T/0101 just inserted above.

    ROLLBACK TO SAVEPOINT after_three;
    -- Rows for (2/ENPM702), (4/ENPM818T), (5/ENPM702) still live.

    -- Replace the failed row with a valid one.
    INSERT INTO enrollment VALUES (2, 'ENPM605', '0101', NULL);
COMMIT;
-- 4 rows committed: (2/ENPM702), (4/ENPM818T), (5/ENPM702), (2/ENPM605)

SELECT student_person_id, course_id, section_no
FROM enrollment
ORDER BY student_person_id, course_id;

-- State after Demo 7:
--   Total enrollment rows: 9
--   ENPM818T/0101 capacity = 30 (untouched by SAVEPOINT demo)


-- ============================================================
-- SECTION 2 (continued): ISOLATION
-- ============================================================


-- ============================================================
-- SNIPPET -- Anomaly 1: Dirty Read
-- Slide: "Anomaly 1: Dirty Read"
-- CANNOT be reproduced in PostgreSQL -- shown for conceptual
-- completeness only. Do not run; included as comments.
-- ============================================================

-- CONNECTION 1 (Session A):
-- BEGIN;
-- UPDATE student SET gpa = 0.5 WHERE person_id = 1;
-- -- NOT committed yet

-- CONNECTION 2 (Session B) -- in PostgreSQL this would NOT see 0.5:
-- SELECT gpa FROM student WHERE person_id = 1;
-- -- PostgreSQL: returns 3.75 (committed value), NOT the uncommitted 0.5.
-- -- PostgreSQL prevents dirty reads entirely.

-- CONNECTION 1 (Session A):
-- ROLLBACK;


-- ============================================================
-- SNIPPET -- Anomaly 2: Non-Repeatable Read (READ COMMITTED)
-- Slide: "Anomaly 2: Non-Repeatable Read -- READ COMMITTED"
-- Requires TWO DataGrip SQL consoles open simultaneously.
-- Run each CONNECTION block in a separate console.
-- Cleanup restores Alice's GPA after the demo.
-- ============================================================

-- ---- Run in CONNECTION 1 (Session A) ----
BEGIN; -- READ COMMITTED by default
SELECT gpa FROM student WHERE person_id = 1;
-- Returns 3.75.

-- ---- While Session A is open, run in CONNECTION 2 (Session B) ----
-- Session B uses autocommit -- no BEGIN needed.
-- UPDATE student SET gpa = 2.0 WHERE person_id = 1;

-- ---- Back in CONNECTION 1 (Session A) ----
SELECT gpa FROM student WHERE person_id = 1;
-- Under READ COMMITTED: returns 2.0 (Session B's commit is visible).
COMMIT;

-- Restore Alice's GPA.
UPDATE student SET gpa = 3.75 WHERE person_id = 1;


-- ============================================================
-- SNIPPET -- Anomaly 2 prevented: REPEATABLE READ
-- Slide: "Preventing the Anomaly -- REPEATABLE READ"
-- Same two-console setup as above.
-- Cleanup restores Alice's GPA.
-- ============================================================

-- ---- Run in CONNECTION 1 (Session A) ----
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT gpa FROM student WHERE person_id = 1;
-- Returns 3.75.

-- ---- While Session A is open, run in CONNECTION 2 (Session B) ----
-- UPDATE student SET gpa = 2.0 WHERE person_id = 1;
-- (autocommit)

-- ---- Back in CONNECTION 1 (Session A) ----
SELECT gpa FROM student WHERE person_id = 1;
-- Under REPEATABLE READ: still returns 3.75.
-- Snapshot was frozen at BEGIN time.
COMMIT;

-- Restore Alice's GPA.
UPDATE student SET gpa = 3.75 WHERE person_id = 1;


-- ============================================================
-- SNIPPET -- Anomaly 3: Phantom Read
-- Slide: "Anomaly 3: Phantom Read"
-- Two-console setup. Cleanup removes the phantom student.
-- ============================================================

-- ---- Run in CONNECTION 1 (Session A) ----
BEGIN;
SELECT count(*) FROM student WHERE gpa > 3.5;
-- Returns 1 (Alice=3.75 only; David=3.20 does not qualify).

-- ---- While Session A is open, run in CONNECTION 2 (Session B) ----
-- INSERT INTO person (first_name, last_name, date_of_birth)
--     VALUES ('New', 'Student', '2001-01-01') RETURNING person_id;
-- -- Use the returned person_id (e.g. 11) in the next statement:
-- INSERT INTO student VALUES (11, '117999999', '2025-08-25',
--     'Good Standing', 3.90);
-- (autocommit)

-- ---- Back in CONNECTION 1 (Session A) ----
SELECT count(*) FROM student WHERE gpa > 3.5;
-- Under READ COMMITTED: returns 2 (phantom row appeared).
COMMIT;

-- Cleanup: remove the phantom student inserted by Session B.
DELETE FROM person WHERE person_id = 11;


-- ============================================================
-- SNIPPET -- Anomaly 4: Write Skew
-- Slide: "Anomaly 4: Write Skew"
-- Two-console setup. Cleanup restores on_call.
-- ============================================================

SELECT * FROM on_call; -- Shows A and B.

-- ---- Run in CONNECTION 1 (Session A) ----
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT count(*) FROM on_call; -- Returns 2: safe to remove one.
-- (do NOT commit yet)

-- ---- Run in CONNECTION 2 (Session B) ----
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT count(*) FROM on_call; -- Also returns 2: safe to remove one.
-- DELETE FROM on_call WHERE doctor = 'B';
-- COMMIT;

-- ---- Back in CONNECTION 1 (Session A) ----
-- DELETE FROM on_call WHERE doctor = 'A';
-- COMMIT;
-- SELECT * FROM on_call; -- 0 rows -- constraint violated.

-- Restore on_call.
INSERT INTO on_call VALUES ('A'), ('B') ON CONFLICT DO NOTHING;


-- ============================================================
-- SNIPPET -- SELECT ... FOR UPDATE
-- Slide: "The Lost Update Problem and SELECT ... FOR UPDATE"
-- (think-prompt / answer-prompt slide)
-- Sets capacity to 1 to make the demo meaningful.
-- Two-console setup to show Session B blocking.
-- Cleanup restores capacity and removes the enrollment.
-- ============================================================

UPDATE course_section SET capacity = 1
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- ---- Run in CONNECTION 1 (Session A) ----
BEGIN;
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101'
    FOR UPDATE;
-- Session A holds the row lock.
-- If you now try the same SELECT FOR UPDATE in Connection 2,
-- it will block until Session A commits or rolls back.

UPDATE course_section
    SET capacity = capacity - 1
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
INSERT INTO enrollment (student_person_id, course_id, section_no)
    VALUES (4, 'ENPM818T', '0101')
    ON CONFLICT DO NOTHING;
COMMIT;
-- Lock released. Session B unblocks and reads capacity = 0.

-- Cleanup.
DELETE FROM enrollment
    WHERE student_person_id = 4
      AND course_id = 'ENPM818T'
      AND grade IS NULL;
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- SECTION 3: psycopg3 -- Python Integration
-- (SQL verification queries run after the Python scripts)
-- ============================================================


-- ============================================================
-- DEMO 8 (psycopg3) -- Minimal connection
-- Slide: demostep{8}
-- Run extra/standalone_test.py first, then verify here.
-- ============================================================

SELECT count(*) AS active_connections
FROM pg_stat_activity
WHERE datname = 'university_db';
-- Expected: at least 1 (the Python script's connection).


-- ============================================================
-- DEMO 9 (psycopg3) -- conn.transaction()
-- Slide: demostep{9}
-- Run extra/demo_transaction.py first.
-- Script should use person_id=5 (Eve), course_id='ENPM702', section_no='0101'
-- Eve is NOT enrolled in ENPM702 so the insert succeeds cleanly.
-- ============================================================

-- Pre-check before running the Python script.
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM702' AND section_no = '0101';
-- Expected: 30.

-- After running extra/demo_transaction.py (successful path):
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM702' AND section_no = '0101';
-- Expected: 29 (one enrollment committed).

SELECT student_person_id, course_id, section_no
FROM enrollment
WHERE student_person_id = 5 AND course_id = 'ENPM702';
-- Expected: one row for Eve.

-- After running the ROLLBACK path (person_id=999):
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM702' AND section_no = '0101';
-- Expected: still 29 (ROLLBACK restored the decrement from the failed attempt).


-- ============================================================
-- DEMO 10 (psycopg3) -- EnrollmentService
-- Slide: demostep{10}
-- Set capacity to 2 before running extra/demo_enrollment_service.py
-- so the section exhausts quickly.
-- ============================================================

UPDATE course_section SET capacity = 2
    WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- After running extra/demo_enrollment_service.py
-- (two successful enrollments, third raises ValueError):
SELECT capacity FROM course_section
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 0.

SELECT count(*) FROM enrollment
    WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: count reflects two new enrollments (plus any seed rows).

-- Reset after demo.
UPDATE course_section SET capacity = 30
    WHERE course_id = 'ENPM818T' AND section_no = '0101';


-- ============================================================
-- FULL RESET
-- Restore the database to clean seed state.
-- Run at the end of a lecture session to reset for next time.
-- ============================================================

UPDATE course_section SET capacity = 30;
UPDATE student SET academic_standing = 'Good Standing'
    WHERE academic_standing != 'Good Standing';
UPDATE student SET gpa = 3.75 WHERE person_id = 1;
UPDATE course SET title = 'Data Storage and Databases'
    WHERE course_id = 'ENPM818T';

-- Remove any enrollment rows added during demos, keeping only seed rows.
DELETE FROM enrollment
    WHERE (student_person_id, course_id, section_no) NOT IN (
        VALUES (1, 'ENPM818T', '0101'),
               (1, 'ENPM605',  '0101'),
               (2, 'ENPM818T', '0101'),
               (4, 'ENPM702',  '0101'),
               (5, 'ENPM818T', '0101')
    );

DELETE FROM professor WHERE person_id NOT IN (3, 6, 7, 8, 9);
DELETE FROM student    WHERE person_id NOT IN (1, 2, 4, 5);
DELETE FROM person     WHERE person_id NOT IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

UPDATE professor SET dept_id = 1   WHERE person_id IN (3, 7);
UPDATE professor SET dept_id = 2   WHERE person_id = 6;
UPDATE professor SET dept_id = 3   WHERE person_id = 8;
UPDATE professor SET dept_id = 4   WHERE person_id = 9;
UPDATE professor SET rank_code = 'Associate' WHERE person_id IN (3, 7, 9);
UPDATE professor SET rank_code = 'Full'      WHERE person_id = 6;
UPDATE professor SET rank_code = 'Assistant' WHERE person_id = 8;

DELETE FROM dept_mapping;
TRUNCATE honors_student, student_archive;
INSERT INTO on_call VALUES ('A'), ('B') ON CONFLICT DO NOTHING;

-- Restore Zara in person (not student) for subsequent use.
INSERT INTO person (person_id, first_name, last_name, date_of_birth)
    OVERRIDING SYSTEM VALUE
    VALUES (10, 'Zara', 'Patel', '2002-05-14')
    ON CONFLICT DO NOTHING;

-- Final verification.
SELECT 'person'       AS tbl, count(*) FROM person
UNION ALL SELECT 'student',      count(*) FROM student
UNION ALL SELECT 'enrollment',   count(*) FROM enrollment
UNION ALL SELECT 'course',       count(*) FROM course
UNION ALL SELECT 'course_prereq',count(*) FROM course_prereq;
-- Expected: person=10, student=4, enrollment=5, course=4, course_prereq=2
