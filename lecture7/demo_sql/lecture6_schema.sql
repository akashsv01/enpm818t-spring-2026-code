-- ============================================================
-- ENPM818T L6 Demo SQL Script
-- university_db
-- ============================================================

-- ============================================================
-- Demo 1: FLOAT vs NUMERIC for GPA
-- ============================================================

-- Step 1a: Create table with FLOAT (wrong choice)
CREATE TABLE grade_wrong (
    student_id INTEGER,
    gpa        FLOAT
);

INSERT INTO grade_wrong VALUES (1, 3.9);

-- Observe: may return 0 rows due to floating-point imprecision
SELECT * FROM grade_wrong WHERE gpa = 3.9;

-- Observe: see the stored value and why the comparison fails
SELECT gpa, gpa = 3.9 AS exact_match FROM grade_wrong;

DROP TABLE grade_wrong;

-- Step 1b: Recreate with NUMERIC (correct choice)
CREATE TABLE grade_correct (
    student_id INTEGER,
    gpa        NUMERIC(3,2)
);

INSERT INTO grade_correct VALUES (1, 3.9);

-- Observe: returns the row; exact decimal storage guarantees the match
SELECT * FROM grade_correct WHERE gpa = 3.9;

-- Observe: stored value is exact; comparison returns true
SELECT gpa, gpa = 3.9 AS exact_match FROM grade_correct;

DROP TABLE grade_correct;

-- ============================================================
-- Demo 2: PRIMARY KEY (simple and composite)
-- ============================================================

-- Step 2a: Simple PK, column-level (unnamed)
CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- Step 2b: Simple PK, table-level (named)
CREATE TABLE course (
    course_id VARCHAR(10)  NOT NULL,
    title     VARCHAR(150) NOT NULL,
    CONSTRAINT pk_course PRIMARY KEY (course_id)
);

-- Step 2c: Composite PK, table-level (named)
CREATE TABLE enrollment (
    student_id INTEGER     NOT NULL,
    course_id  VARCHAR(10) NOT NULL,
    semester   CHAR(6)     NOT NULL,
    grade      CHAR(1),
    CONSTRAINT pk_enrollment
        PRIMARY KEY (student_id, course_id, semester)
);

-- Inspect constraint names: run in psql
-- \d department  -> look for "department_pkey" (system-generated)
-- \d course      -> look for "pk_course" (named)
-- \d enrollment  -> look for "pk_enrollment" (named)

-- Step 2d: Insert valid enrollment rows
INSERT INTO enrollment (student_id, course_id, semester)
    VALUES (42, 'ENPM818T', '202601');
INSERT INTO enrollment (student_id, course_id, semester)
    VALUES (42, 'ENPM605',  '202601');

-- Step 2e: Attempt duplicate triple; observe error naming pk_enrollment
INSERT INTO enrollment (student_id, course_id, semester)
    VALUES (42, 'ENPM818T', '202601');
-- ERROR: duplicate key value violates unique constraint "pk_enrollment"

DROP TABLE enrollment;
DROP TABLE course;
DROP TABLE department;

-- ============================================================
-- Demo 3: Named vs. Unnamed PRIMARY KEY constraints
-- ============================================================

-- Step 3a: Unnamed PK (column-level); system generates the name
CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

INSERT INTO department OVERRIDING SYSTEM VALUE
    VALUES (1, 'Engineering');

-- Observe: error message says "department_pkey" (not descriptive)
INSERT INTO department OVERRIDING SYSTEM VALUE
    VALUES (1, 'Mathematics');
-- ERROR: duplicate key value violates unique constraint "department_pkey"

-- Step 3b: Named PK (table-level); your prefix appears in the error
CREATE TABLE course (
    course_id VARCHAR(10)  NOT NULL,
    title     VARCHAR(150) NOT NULL,
    CONSTRAINT pk_course PRIMARY KEY (course_id)
);

INSERT INTO course VALUES ('ENPM818T', 'Databases');

-- Observe: error message says "pk_course" (immediately actionable)
INSERT INTO course VALUES ('ENPM818T', 'Databases');
-- ERROR: duplicate key value violates unique constraint "pk_course"

-- Inspect in psql:
-- \d department  -> constraint listed as "department_pkey PRIMARY KEY"
-- \d course      -> constraint listed as "pk_course PRIMARY KEY"

DROP TABLE course;
DROP TABLE department;

-- ============================================================
-- Demo 4: SERIAL silent bypass
-- ============================================================

CREATE TABLE department (
    dept_id   SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- Step 1: explicit insert; sequence counter never advances
INSERT INTO department (dept_id, dept_name)
    VALUES (1, 'Computer Science');

-- Step 2: explicit insert; sequence counter still frozen at 1
INSERT INTO department (dept_id, dept_name)
    VALUES (2, 'Mathematics');

-- Observe: counter is still 1 despite two rows existing
SELECT last_value FROM department_dept_id_seq;

-- Step 3: auto insert; nextval() returns 1 and collides with row 1
INSERT INTO department (dept_name)
    VALUES ('Physics');
-- ERROR: duplicate key value violates unique constraint "department_pkey"
-- DETAIL: Key (dept_id)=(1) already exists.

DROP TABLE department;

-- ============================================================
-- Demo 5: GENERATED ALWAYS AS IDENTITY -- safe alternative
-- ============================================================

CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- Bypass attempt: rejected immediately
INSERT INTO department (dept_id, dept_name)
    VALUES (1, 'Computer Science');
-- ERROR: cannot insert into column "dept_id"
-- DETAIL: Column "dept_id" is an identity column defined as GENERATED ALWAYS

-- Legal override: succeeds but does not advance the sequence
INSERT INTO department (dept_id, dept_name)
    OVERRIDING SYSTEM VALUE
    VALUES (1, 'Computer Science');

-- Observe: counter is still 1 despite the row existing
SELECT last_value FROM department_dept_id_seq;

DROP TABLE department;

-- Customized sequence: starts at 1000
CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY
            (START WITH 1000 INCREMENT BY 1)
        PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- Inspect: \d department shows sequence starting at 1000
INSERT INTO department (dept_name) VALUES ('Computer Science');
INSERT INTO department (dept_name) VALUES ('Mathematics');

-- Observe: dept_id values are 1000 and 1001
SELECT * FROM department;

DROP TABLE department;

-- ============================================================
-- Demo 6: ISA shared-PK pattern
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE student (
    person_id  INTEGER PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT fk_student_person
        FOREIGN KEY (person_id)
            REFERENCES person (person_id)
            ON DELETE CASCADE
);

-- Insert supertypes; identity is generated here only
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson');
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');

-- Insert subtypes using the generated person_id values
INSERT INTO student (person_id, student_id) VALUES (1, '117453210');
INSERT INTO student (person_id, student_id) VALUES (2, '117453211');

-- Observe: both rows exist in both tables
SELECT * FROM person;
SELECT * FROM student;

-- Attempt to insert a student with no matching person row
INSERT INTO student (person_id, student_id) VALUES (99, '117453299');
-- ERROR: insert or update on table "student" violates foreign key
-- constraint "fk_student_person"
-- DETAIL: Key (person_id)=(99) is not present in table "person".

-- Delete Alice from person; observe CASCADE removes her student row too
DELETE FROM person WHERE person_id = 1;

SELECT * FROM person;   -- Alice gone
SELECT * FROM student;  -- Alice's student row gone automatically

DROP TABLE student;
DROP TABLE person;

-- ============================================================
-- Demo 7: NO ACTION vs RESTRICT
-- ============================================================

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

INSERT INTO department (dept_name) VALUES ('Computer Science');

-- --------------------------------------------------------
-- Variant A: RESTRICT -- error fires immediately
-- --------------------------------------------------------
CREATE TABLE professor_restrict (
    person_id INTEGER PRIMARY KEY,
    dept_id   INTEGER,
    CONSTRAINT fk_prof_restrict
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE RESTRICT
);

INSERT INTO professor_restrict VALUES (1, 1);

-- Observe: error fires before the statement completes
BEGIN;
    DELETE FROM department WHERE dept_id = 1;
    -- ERROR: update or delete on table "department" violates foreign key
    -- constraint "fk_prof_restrict" on table "professor_restrict"
ROLLBACK;

-- --------------------------------------------------------
-- Variant B: NO ACTION -- error fires at end of statement
-- --------------------------------------------------------
CREATE TABLE professor_no_action (
    person_id INTEGER PRIMARY KEY,
    dept_id   INTEGER,
    CONSTRAINT fk_prof_no_action
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE NO ACTION
);

INSERT INTO professor_no_action VALUES (1, 1);

-- Observe: same blocking behavior as RESTRICT for a single statement
BEGIN;
    DELETE FROM department WHERE dept_id = 1;
    -- ERROR: same violation, fires at end of statement
ROLLBACK;

-- --------------------------------------------------------
-- Variant C: NO ACTION DEFERRABLE -- check deferred to COMMIT
-- --------------------------------------------------------
CREATE TABLE professor_deferred (
    person_id INTEGER PRIMARY KEY,
    dept_id   INTEGER,
    CONSTRAINT fk_prof_deferred
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE NO ACTION
            DEFERRABLE INITIALLY DEFERRED
);

INSERT INTO professor_deferred VALUES (1, 1);

-- Observe: deleting both the child and parent inside the same
-- transaction satisfies the FK at COMMIT; no error
BEGIN;
    DELETE FROM professor_deferred WHERE dept_id = 1;
    DELETE FROM department WHERE dept_id = 1;
COMMIT;

-- Observe: both tables are now empty
SELECT * FROM professor_deferred;
SELECT * FROM department;

DROP TABLE professor_deferred;
DROP TABLE professor_no_action;
DROP TABLE professor_restrict;
DROP TABLE department;

-- ============================================================
-- Demo 8: ON DELETE CASCADE
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE student (
    person_id  INTEGER PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL UNIQUE,
    CONSTRAINT fk_student_person
        FOREIGN KEY (person_id)
            REFERENCES person (person_id)
            ON DELETE CASCADE
);

CREATE TABLE enrollment (
    person_id  INTEGER     NOT NULL,
    course_id  VARCHAR(20) NOT NULL,
    section_no VARCHAR(20) NOT NULL,
    grade      VARCHAR(2),
    CONSTRAINT fk_enr_student
        FOREIGN KEY (person_id)
            REFERENCES student (person_id)
            ON DELETE CASCADE
);

-- Insert parent rows
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson'); -- person_id = 1
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');   -- person_id = 2

-- Insert student rows
INSERT INTO student VALUES (1, '117453210');
INSERT INTO student VALUES (2, '117453211');

-- Insert enrollment rows
INSERT INTO enrollment VALUES (1, 'CS301', '101',  'A');
INSERT INTO enrollment VALUES (1, 'CS401', 'A01',  'B+');
INSERT INTO enrollment VALUES (2, 'CS301', 'R002', 'A-');

-- Observe: three enrollment rows exist
SELECT * FROM enrollment;

-- Delete student 1 (Alice); CASCADE removes her enrollment rows
DELETE FROM student WHERE person_id = 1;

-- Observe: only Bob's enrollment row remains
SELECT * FROM enrollment;

DROP TABLE enrollment;
DROP TABLE student;
DROP TABLE person;

-- ============================================================
-- Demo 9: ON DELETE SET NULL
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER,
    CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE SET NULL
);

-- Insert departments
INSERT INTO department (dept_name) VALUES ('Computer Science'); -- dept_id = 1
INSERT INTO department (dept_name) VALUES ('Mathematics');      -- dept_id = 2

-- Insert persons
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson'); -- person_id = 1
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');   -- person_id = 2
INSERT INTO person (first_name, last_name) VALUES ('Carol', 'Davis');   -- person_id = 3

-- Insert professors
INSERT INTO professor VALUES (1, 1); -- Alice in CS
INSERT INTO professor VALUES (2, 1); -- Bob   in CS
INSERT INTO professor VALUES (3, 2); -- Carol in Math

-- Observe: Alice and Bob assigned to dept 1
SELECT p.first_name, pr.dept_id
FROM professor pr JOIN person p ON pr.person_id = p.person_id;

-- Delete CS department; Alice and Bob survive with dept_id = NULL
DELETE FROM department WHERE dept_id = 1;

-- Observe: Alice and Bob unassigned; Carol unchanged
SELECT p.first_name, pr.dept_id
FROM professor pr JOIN person p ON pr.person_id = p.person_id;

-- Demonstrate why SET NULL requires a nullable column
ALTER TABLE professor ALTER COLUMN dept_id SET NOT NULL;
-- ERROR: column "dept_id" of relation "professor" contains null values

DROP TABLE professor;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 10: ON DELETE SET DEFAULT
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

-- dept_id uses OVERRIDING SYSTEM VALUE so we can insert dept_id = 0
CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- Insert the catch-all sentinel row first; dept_id must be 0
INSERT INTO department (dept_id, dept_name)
    OVERRIDING SYSTEM VALUE
    VALUES (0, 'Unassigned');

INSERT INTO department (dept_name) VALUES ('Computer Science'); -- dept_id = 1
INSERT INTO department (dept_name) VALUES ('Mathematics');      -- dept_id = 2

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER DEFAULT 0,
    CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE SET DEFAULT
);

-- Insert persons
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson'); -- person_id = 1
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');   -- person_id = 2
INSERT INTO person (first_name, last_name) VALUES ('Carol', 'Davis');   -- person_id = 3

-- Insert professors
INSERT INTO professor VALUES (1, 1); -- Alice in CS
INSERT INTO professor VALUES (2, 1); -- Bob   in CS
INSERT INTO professor VALUES (3, 2); -- Carol in Math

-- Observe: Alice and Bob in dept 1
SELECT p.first_name, pr.dept_id
FROM professor pr JOIN person p ON pr.person_id = p.person_id;

-- Delete CS; Alice and Bob fall back to dept_id = 0 (Unassigned)
DELETE FROM department WHERE dept_id = 1;

-- Observe: Alice and Bob now in dept 0; Carol unchanged
SELECT p.first_name, pr.dept_id
FROM professor pr JOIN person p ON pr.person_id = p.person_id;

-- Demonstrate the requirement: default value must exist as a valid FK target
-- Delete the Unassigned sentinel and try the same operation again
DELETE FROM department WHERE dept_id = 0;
INSERT INTO professor VALUES (1, 2); -- re-insert Alice in Math
DELETE FROM department WHERE dept_id = 2;
-- ERROR: insert or update on table "professor" violates foreign key
-- constraint "fk_prof_dept"
-- DETAIL: Key (dept_id)=(0) is not present in table "department".

DROP TABLE professor;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 11: Deferrable foreign keys
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson');

CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE,
    CONSTRAINT fk_dept_chair
        FOREIGN KEY (chair_id)
            REFERENCES professor (person_id)
            ON DELETE SET NULL
            DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER NOT NULL,
    hire_date DATE    NOT NULL,
    rank_code VARCHAR(20) NOT NULL,
    CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE RESTRICT
);

-- Step 11a: three-step pattern inside a transaction
-- FK check is deferred to COMMIT; temporary inconsistency is tolerated
BEGIN;
    INSERT INTO department (dept_name)
        VALUES ('Computer Science');           -- chair_id is NULL; OK
    INSERT INTO professor (person_id, dept_id, hire_date, rank_code)
        VALUES (1, 1, CURRENT_DATE, 'Associate'); -- references dept just created
    UPDATE department
        SET chair_id = 1
        WHERE dept_name = 'Computer Science';  -- wires the chair FK
COMMIT;

-- Observe: department has chair_id = 1; professor exists in dept 1
SELECT d.dept_name, d.chair_id, p.first_name || ' ' || p.last_name AS chair
FROM department d
JOIN professor  pr ON d.chair_id  = pr.person_id
JOIN person     p  ON pr.person_id = p.person_id;

-- Step 11b: same inserts without BEGIN/COMMIT; each is its own transaction
-- The UPDATE fails immediately because the deferred check fires per-statement
UPDATE department SET chair_id = 1 WHERE dept_name = 'Computer Science';
-- ERROR if professor row did not exist yet

-- Step 11c: recreate department as NOT DEFERRABLE and confirm
-- the FK fires immediately even inside BEGIN/COMMIT
DROP TABLE professor;
DROP TABLE department;

CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE,
    CONSTRAINT fk_dept_chair
        FOREIGN KEY (chair_id)
            REFERENCES professor (person_id)
            ON DELETE SET NULL
            NOT DEFERRABLE
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER NOT NULL,
    hire_date DATE    NOT NULL,
    rank_code VARCHAR(20) NOT NULL,
    CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE RESTRICT
);

BEGIN;
    INSERT INTO department (dept_name) VALUES ('Computer Science');
    INSERT INTO professor (person_id, dept_id, hire_date, rank_code)
        VALUES (1, 1, CURRENT_DATE, 'Associate');
    UPDATE department SET chair_id = 1 WHERE dept_name = 'Computer Science';
    -- ERROR: insert or update on table "department" violates foreign key
    -- constraint "fk_dept_chair"
    -- DETAIL: Key (chair_id)=(1) is not present in table "professor".
ROLLBACK;

DROP TABLE professor;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 12: Deferrable FK syntax -- Mode 1 vs Mode 2
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson');

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER NOT NULL,
    hire_date DATE    NOT NULL,
    rank_code VARCHAR(20) NOT NULL
);

-- --------------------------------------------------------
-- Mode 1: DEFERRABLE INITIALLY DEFERRED
-- Check postponed to COMMIT automatically for every transaction
-- --------------------------------------------------------
CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE,
    CONSTRAINT fk_dept_chair
        FOREIGN KEY (chair_id)
            REFERENCES professor (person_id)
            ON DELETE SET NULL
            DEFERRABLE INITIALLY DEFERRED
);

ALTER TABLE professor
    ADD CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE RESTRICT;

-- No SET CONSTRAINTS needed; deferral is automatic
BEGIN;
    INSERT INTO department (dept_name) VALUES ('Computer Science');
    INSERT INTO professor (person_id, dept_id, hire_date, rank_code)
        VALUES (1, 1, CURRENT_DATE, 'Associate');
    UPDATE department SET chair_id = 1 WHERE dept_name = 'Computer Science';
COMMIT;
-- Observe: succeeds with no extra syntax

DROP TABLE professor;
DROP TABLE department;

-- --------------------------------------------------------
-- Mode 2: DEFERRABLE INITIALLY IMMEDIATE
-- Immediate by default; transactions must opt in explicitly
-- --------------------------------------------------------
CREATE TABLE department (
    dept_id   INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    chair_id  INTEGER UNIQUE,
    CONSTRAINT fk_dept_chair
        FOREIGN KEY (chair_id)
            REFERENCES professor (person_id)
            ON DELETE SET NULL
            DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY
        REFERENCES person (person_id)
        ON DELETE CASCADE,
    dept_id   INTEGER NOT NULL,
    hire_date DATE    NOT NULL,
    rank_code VARCHAR(20) NOT NULL,
    CONSTRAINT fk_prof_dept
        FOREIGN KEY (dept_id)
            REFERENCES department (dept_id)
            ON DELETE RESTRICT
);

-- Without SET CONSTRAINTS: error fires immediately
BEGIN;
    INSERT INTO department (dept_name) VALUES ('Computer Science');
    INSERT INTO professor (person_id, dept_id, hire_date, rank_code)
        VALUES (1, 1, CURRENT_DATE, 'Associate');
    UPDATE department SET chair_id = 1 WHERE dept_name = 'Computer Science';
    -- ERROR: insert or update on table "department" violates foreign key
    -- constraint "fk_dept_chair"
ROLLBACK;

-- With SET CONSTRAINTS: transaction opts in; succeeds
BEGIN;
    SET CONSTRAINTS fk_dept_chair DEFERRED;
    INSERT INTO department (dept_name) VALUES ('Computer Science');
    INSERT INTO professor (person_id, dept_id, hire_date, rank_code)
        VALUES (1, 1, CURRENT_DATE, 'Associate');
    UPDATE department SET chair_id = 1 WHERE dept_name = 'Computer Science';
COMMIT;
-- Observe: succeeds because deferral was requested explicitly

DROP TABLE professor;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 13: UNIQUE and the NULL trap
-- ============================================================

CREATE TABLE vehicle (
    vehicle_id INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    make       VARCHAR(50) NOT NULL,
    model      VARCHAR(50) NOT NULL,
    plate      VARCHAR(10) UNIQUE
);

INSERT INTO vehicle (make, model)
    VALUES ('Toyota', 'Camry');             /* OK */
INSERT INTO vehicle (make, model)
    VALUES ('Honda',  'Civic');             /* OK */
INSERT INTO vehicle (make, model, plate)
    VALUES ('Ford', 'F-150', 'ABC-1234'); /* OK */
INSERT INTO vehicle (make, model, plate)
    VALUES ('BMW',  'X5',    'ABC-1234'); /* FAIL */
-- ERROR: duplicate key value violates unique constraint "vehicle_plate_key"

-- Observe: rows 1 and 2 coexist despite both having plate = NULL
SELECT * FROM vehicle;

-- Observe: NULL compared to itself returns NULL, not TRUE
SELECT plate, plate = plate AS self_equal
FROM vehicle
WHERE vehicle_id = 1;

-- Observe: adding NOT NULL fails because two NULL rows already exist
ALTER TABLE vehicle ALTER COLUMN plate SET NOT NULL;
-- ERROR: column "plate" of relation "vehicle" contains null values

DROP TABLE vehicle;

-- ============================================================
-- Demo 14: UNIQUE NULLS NOT DISTINCT
-- ============================================================

-- Step 14a: NULLS NOT DISTINCT -- at most one NULL allowed
CREATE TABLE device (
    device_id INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model     VARCHAR(50) NOT NULL,
    serial_no VARCHAR(30) UNIQUE NULLS NOT DISTINCT
);

INSERT INTO device (model, serial_no) VALUES ('RoboArm X1', 'SN-00142'); /* OK */
INSERT INTO device (model, serial_no) VALUES ('RoboArm X1', 'SN-00143'); /* OK */
INSERT INTO device (model)            VALUES ('RoboArm X1');              /* OK */
INSERT INTO device (model)            VALUES ('RoboArm X1');              /* FAIL */
-- ERROR: duplicate key value violates unique constraint "device_serial_no_key"

-- Observe: three rows exist; only one NULL is present
SELECT * FROM device;

DROP TABLE device;

-- Step 14b: plain UNIQUE -- multiple NULLs allowed
CREATE TABLE device (
    device_id INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model     VARCHAR(50) NOT NULL,
    serial_no VARCHAR(30) UNIQUE
);

INSERT INTO device (model, serial_no) VALUES ('RoboArm X1', 'SN-00142'); /* OK */
INSERT INTO device (model, serial_no) VALUES ('RoboArm X1', 'SN-00143'); /* OK */
INSERT INTO device (model)            VALUES ('RoboArm X1');              /* OK */
INSERT INTO device (model)            VALUES ('RoboArm X1');              /* OK */

-- Observe: four rows exist; two NULLs coexist
SELECT * FROM device;

DROP TABLE device;

-- ============================================================
-- Demo 15: CHECK table-level cross-column rules
-- ============================================================

-- Step 15a: date range check
CREATE TABLE contract (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    CONSTRAINT chk_dates CHECK (start_date < end_date)
);

INSERT INTO contract (start_date, end_date)
    VALUES ('2026-01-01', '2026-12-31'); /* OK */
INSERT INTO contract (start_date, end_date)
    VALUES ('2026-06-01', '2026-01-01'); /* FAIL: end before start */
-- ERROR: new row for relation "contract" violates check constraint "chk_dates"

INSERT INTO contract (start_date, end_date)
    VALUES ('2026-03-01', '2026-03-01'); /* FAIL: equal dates */
-- ERROR: new row for relation "contract" violates check constraint "chk_dates"

-- Observe: NULL trap -- CHECK evaluates to UNKNOWN, row passes silently
-- end_date is NOT NULL so this will fail on NOT NULL, not CHECK
-- Remove NOT NULL to expose the trap:
ALTER TABLE contract ALTER COLUMN end_date DROP NOT NULL;
INSERT INTO contract (start_date, end_date)
    VALUES ('2026-01-01', NULL); /* OK -- CHECK returns UNKNOWN, not FALSE */

SELECT * FROM contract;

DROP TABLE contract;

-- Step 15b: IN-list vocabulary check
CREATE TABLE person (
    person_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE student (
    person_id         INTEGER PRIMARY KEY
        REFERENCES person (person_id) ON DELETE CASCADE,
    academic_standing VARCHAR(30) NOT NULL,
    CONSTRAINT chk_standing
        CHECK (academic_standing IN (
            'Good Standing', 'Probation',
            'Suspended',     'Dismissed'))
);

INSERT INTO person DEFAULT VALUES; -- person_id = 1
INSERT INTO person DEFAULT VALUES; -- person_id = 2

INSERT INTO student VALUES (1, 'Good Standing'); /* OK */
INSERT INTO student VALUES (2, 'Expelled');      /* FAIL: outside vocabulary */
-- ERROR: new row for relation "student" violates check constraint "chk_standing"

-- Observe: NULL blocked by NOT NULL, not by CHECK
INSERT INTO student VALUES (2, NULL);
-- ERROR: null value in column "academic_standing" violates no

-- ============================================================
-- Demo 16: Categories -- exclusive-arc CHECK pattern
-- ============================================================

CREATE TABLE veh_person (
    ssn       VARCHAR(11) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);

CREATE TABLE company (
    tax_id      VARCHAR(10) PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL
);

CREATE TABLE bank (
    routing_no VARCHAR(9) PRIMARY KEY,
    bank_name  VARCHAR(100) NOT NULL
);

CREATE TABLE vehicle_owner (
    owner_id        INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_type      VARCHAR(10) NOT NULL,
    person_ssn      VARCHAR(11),
    company_tax_id  VARCHAR(10),
    bank_routing_no VARCHAR(9),
    ownership_date  DATE NOT NULL,
    CONSTRAINT fk_owner_person
        FOREIGN KEY (person_ssn)
            REFERENCES veh_person (ssn)
            ON DELETE CASCADE,
    CONSTRAINT fk_owner_company
        FOREIGN KEY (company_tax_id)
            REFERENCES company (tax_id)
            ON DELETE CASCADE,
    CONSTRAINT fk_owner_bank
        FOREIGN KEY (bank_routing_no)
            REFERENCES bank (routing_no)
            ON DELETE CASCADE,
    CONSTRAINT chk_exclusive_arc
        CHECK (
            (person_ssn      IS NOT NULL)::INT +
            (company_tax_id  IS NOT NULL)::INT +
            (bank_routing_no IS NOT NULL)::INT = 1)
);

-- Insert parent rows
INSERT INTO veh_person VALUES ('123-45-6789', 'Alice Johnson');
INSERT INTO company    VALUES ('TX-9876543',  'Acme Corp');
INSERT INTO bank       VALUES ('021000021',   'First National Bank');

-- Valid rows: exactly one FK non-null per row
INSERT INTO vehicle_owner (owner_type, person_ssn,     ownership_date)
    VALUES ('person',  '123-45-6789', CURRENT_DATE); /* OK: arc sum = 1 */
INSERT INTO vehicle_owner (owner_type, company_tax_id, ownership_date)
    VALUES ('company', 'TX-9876543',  CURRENT_DATE); /* OK: arc sum = 1 */
INSERT INTO vehicle_owner (owner_type, bank_routing_no, ownership_date)
    VALUES ('bank',    '021000021',   CURRENT_DATE); /* OK: arc sum = 1 */

-- Verify arc sum is 1 for all valid rows
SELECT owner_id,
       owner_type,
       (person_ssn      IS NOT NULL)::INT +
       (company_tax_id  IS NOT NULL)::INT +
       (bank_routing_no IS NOT NULL)::INT AS arc_sum
FROM vehicle_owner;

-- Two FKs non-null: arc sum = 2; rejected
INSERT INTO vehicle_owner (owner_type, person_ssn, company_tax_id, ownership_date)
    VALUES ('person', '123-45-6789', 'TX-9876543', CURRENT_DATE);
-- ERROR: new row for relation "vehicle_owner" violates check constraint
-- "chk_exclusive_arc"

-- All FKs null: arc sum = 0; rejected
INSERT INTO vehicle_owner (owner_type, ownership_date)
    VALUES ('unknown', CURRENT_DATE);
-- ERROR: new row for relation "vehicle_owner" violates check constraint
-- "chk_exclusive_arc"

DROP TABLE vehicle_owner;
DROP TABLE bank;
DROP TABLE company;
DROP TABLE veh_person;

-- ============================================================
-- Demo 17: EXCLUDE constraint with GIST and range overlap
-- ============================================================

-- btree_gist is required to use = with GIST on non-range types
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE exam_schedule (
    exam_id    INTEGER
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room       VARCHAR(20) NOT NULL,
    seat_range INT4RANGE   NOT NULL,
    CONSTRAINT no_seat_overlap
        EXCLUDE USING GIST (
            room       WITH =,
            seat_range WITH &&
        )
);

INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1202', '[1,50)');   /* OK: first row, no conflict */
INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1202', '[40,80)');  /* FAIL: overlaps [1,50) at seats 40-49 */
-- ERROR: conflicting key value violates exclusion constraint "no_seat_overlap"

INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1202', '[51,100)'); /* OK: no shared seat with [1,50) */
INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1104', '[1,50)');   /* OK: different room */

-- Observe: three rows exist
SELECT * FROM exam_schedule;

-- [50,80) is adjacent to [1,50) but does not overlap; succeeds
INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1202', '[50,80)');  /* OK: [1,50) excludes seat 50 */

-- Observe: now four rows; [50,80) sits between [1,50) and [51,100)
SELECT * FROM exam_schedule ORDER BY room, seat_range;

-- Same range in a different room; room condition fails so constraint does not fire
INSERT INTO exam_schedule (room, seat_range)
    VALUES ('EGR 1104', '[51,100)'); /* OK: different room */

-- Demonstrate that UNIQUE would not catch the overlap
-- [1,50) and [40,80) are different values so UNIQUE would accept both
SELECT '[1,50)'::INT4RANGE && '[40,80)'::INT4RANGE AS overlaps; /* TRUE */
SELECT '[1,50)'::INT4RANGE =  '[40,80)'::INT4RANGE AS equal;    /* FALSE */

DROP TABLE exam_schedule;

-- ============================================================
-- Demo 18: Verifying the schema with catalog views
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE student (
    person_id         INTEGER PRIMARY KEY,
    student_id        VARCHAR(20) NOT NULL UNIQUE,
    admission_date    DATE        NOT NULL,
    gpa               NUMERIC(3,2),
    academic_standing VARCHAR(30) NOT NULL,
    CONSTRAINT chk_gpa
        CHECK (gpa >= 0.0 AND gpa <= 4.0),
    CONSTRAINT chk_standing
        CHECK (academic_standing IN (
            'Good Standing', 'Probation',
            'Suspended', 'Dismissed')),
    CONSTRAINT fk_student_person
        FOREIGN KEY (person_id)
            REFERENCES person (person_id)
            ON DELETE CASCADE
);

CREATE TABLE grad_student (
    person_id    INTEGER PRIMARY KEY,
    thesis_topic VARCHAR(200),
    CONSTRAINT fk_grad_student
        FOREIGN KEY (person_id)
            REFERENCES student (person_id)
            ON DELETE CASCADE
);

-- Insert persons
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson'); -- person_id = 1
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');   -- person_id = 2
INSERT INTO person (first_name, last_name) VALUES ('Carol', 'Davis');   -- person_id = 3

-- Insert students
INSERT INTO student VALUES (1, '117453210', '2024-08-26', 3.75, 'Good Standing');
INSERT INTO student VALUES (2, '117453211', '2024-08-26', 2.10, 'Probation');
INSERT INTO student VALUES (3, '117453212', '2023-08-28', 3.90, 'Good Standing');

-- Insert grad student
INSERT INTO grad_student VALUES (3, 'Autonomous Vehicle Perception');

-- --------------------------------------------------------
-- Catalog queries
-- --------------------------------------------------------

-- List all constraints on the student table with their types
SELECT constraint_name,
       constraint_type
FROM information_schema.table_constraints
WHERE table_name   = 'student'
  AND table_schema = 'public'
ORDER BY constraint_type, constraint_name;

-- List all FK delete and update actions for the entire schema
SELECT tc.table_name,
       tc.constraint_name,
       rc.delete_rule,
       rc.update_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- Check current sequence values for all sequences in public schema
SELECT sequencename,
       last_value,
       increment_by,
       start_value
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY sequencename;

-- List every table with a FK pointing at student
SELECT tc.table_name AS child_table,
       tc.constraint_name,
       rc.delete_rule
FROM information_schema.table_constraints      tc
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema    = 'public'
  AND rc.unique_constraint_name IN (
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name   = 'student'
        AND table_schema = 'public'
  )
ORDER BY child_table;

DROP TABLE grad_student;
DROP TABLE student;
DROP TABLE person;

-- ============================================================
-- Demo 19: Common ALTER TABLE operations
-- ============================================================

CREATE TABLE person (
    person_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    last_name   VARCHAR(50) NOT NULL,
    state       CHAR(2)
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE course (
    course_id VARCHAR(10)  PRIMARY KEY,
    dept_id   INTEGER      NOT NULL REFERENCES department (dept_id),
    title     VARCHAR(150) NOT NULL,
    credits   INTEGER      NOT NULL
);

CREATE TABLE course_section (
    course_id  VARCHAR(10) NOT NULL REFERENCES course (course_id),
    section_no VARCHAR(10) NOT NULL,
    schedule   VARCHAR(100),
    CONSTRAINT pk_course_section PRIMARY KEY (course_id, section_no)
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY REFERENCES person (person_id),
    dept_id   INTEGER NOT NULL REFERENCES department (dept_id),
    hire_date DATE    NOT NULL,
    salary    NUMERIC(12,2)
);

-- Insert sample data
INSERT INTO department (dept_name) VALUES ('Computer Science');
INSERT INTO person (first_name, middle_name, last_name, state)
    VALUES ('Alice', 'M', 'Johnson', 'MD');
INSERT INTO course VALUES ('ENPM818T', 1, 'Data Storage and Databases', 3);
INSERT INTO course_section VALUES ('ENPM818T', '0101', 'MWF 10:00');
INSERT INTO professor VALUES (1, 1, '2020-08-01', 95000.00);

-- --------------------------------------------------------
-- Add a nullable column: instant, no table rewrite
-- --------------------------------------------------------
ALTER TABLE course ADD COLUMN description TEXT;

-- Confirm the column exists with NULL for existing rows
SELECT course_id, description FROM course;

-- --------------------------------------------------------
-- ADD COLUMN NOT NULL with no default: fails
-- --------------------------------------------------------
ALTER TABLE course ADD COLUMN is_archived BOOLEAN NOT NULL;
-- ERROR: column "is_archived" of relation "course" contains null values

-- --------------------------------------------------------
-- ADD COLUMN NOT NULL with DEFAULT: instant in PG 11+
-- --------------------------------------------------------
ALTER TABLE course ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE;

-- Confirm existing rows received the default value
SELECT course_id, is_archived FROM course;

-- --------------------------------------------------------
-- Set a default on an existing column
-- --------------------------------------------------------
ALTER TABLE course ALTER COLUMN credits SET DEFAULT 3;

-- --------------------------------------------------------
-- Change a column type (compatible: CHAR(2) to CHAR(3))
-- --------------------------------------------------------
ALTER TABLE person ALTER COLUMN state TYPE CHAR(3);

-- --------------------------------------------------------
-- Add a named CHECK constraint
-- --------------------------------------------------------
ALTER TABLE professor
    ADD CONSTRAINT chk_hire_date
        CHECK (hire_date >= '1900-01-01');

-- Confirm constraint exists
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'professor' AND table_schema = 'public';

-- --------------------------------------------------------
-- Drop a named constraint
-- --------------------------------------------------------
ALTER TABLE professor DROP CONSTRAINT chk_hire_date;

-- --------------------------------------------------------
-- Rename a column: instant, no table rewrite
-- --------------------------------------------------------
ALTER TABLE course_section RENAME COLUMN schedule TO meeting_pattern;

-- Confirm the rename
SELECT column_name FROM information_schema.columns
WHERE table_name = 'course_section' AND table_schema = 'public';

-- --------------------------------------------------------
-- Drop a column
-- --------------------------------------------------------
ALTER TABLE person DROP COLUMN middle_name;

-- Confirm the column is gone
SELECT column_name FROM information_schema.columns
WHERE table_name = 'person' AND table_schema = 'public';

DROP TABLE professor;
DROP TABLE course_section;
DROP TABLE course;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 20: Safe migration pattern for large tables
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE professor (
    person_id INTEGER PRIMARY KEY REFERENCES person (person_id),
    dept_id   INTEGER NOT NULL REFERENCES department (dept_id),
    hire_date DATE    NOT NULL
);

-- Insert sample data
INSERT INTO department (dept_name) VALUES ('Computer Science');
INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson');
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');
INSERT INTO professor VALUES (1, 1, '2020-08-01');
INSERT INTO professor VALUES (2, 1, '2018-01-15');

-- --------------------------------------------------------
-- Demonstrate why the naive approach fails
-- --------------------------------------------------------
ALTER TABLE professor ADD COLUMN office_number VARCHAR(10) NOT NULL;
-- ERROR: column "office_number" of relation "professor" contains null values

-- --------------------------------------------------------
-- Step 1: add nullable; instant on any table size
-- --------------------------------------------------------
ALTER TABLE professor ADD COLUMN office_number VARCHAR(10);

-- Confirm existing rows have NULL
SELECT person_id, office_number FROM professor;

-- --------------------------------------------------------
-- Step 2: backfill existing rows
-- In production this would use batches with LIMIT
-- --------------------------------------------------------
UPDATE professor
    SET office_number = 'TBD'
    WHERE office_number IS NULL;

-- Confirm all rows are backfilled
SELECT person_id, office_number FROM professor;

-- --------------------------------------------------------
-- Step 3: add constraint as NOT VALID
-- Skips scanning existing rows; new writes are checked immediately
-- --------------------------------------------------------
ALTER TABLE professor
    ADD CONSTRAINT nn_office_number
        CHECK (office_number IS NOT NULL)
        NOT VALID;

-- Confirm constraint exists but is not yet validated
SELECT conname, convalidated
FROM pg_constraint
WHERE conrelid = 'professor'::regclass;

-- New inserts are checked immediately even before validation
INSERT INTO professor (person_id, dept_id, hire_date, office_number)
    VALUES (1, 1, CURRENT_DATE, NULL);
-- ERROR: new row for relation "professor" violates check constraint
-- "nn_office_number"

-- --------------------------------------------------------
-- Step 4: validate with a weaker lock
-- Reads continue during this scan
-- --------------------------------------------------------
ALTER TABLE professor VALIDATE CONSTRAINT nn_office_number;

-- Confirm constraint is now marked valid
SELECT conname, convalidated
FROM pg_constraint
WHERE conrelid = 'professor'::regclass;

DROP TABLE professor;
DROP TABLE department;
DROP TABLE person;

-- ============================================================
-- Demo 21: DELETE, TRUNCATE, and DROP
-- ============================================================

CREATE TABLE person (
    person_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL
);

CREATE TABLE student (
    person_id  INTEGER PRIMARY KEY
        REFERENCES person (person_id) ON DELETE CASCADE,
    student_id VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE department (
    dept_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE course (
    course_id VARCHAR(10)  PRIMARY KEY,
    dept_id   INTEGER      NOT NULL REFERENCES department (dept_id),
    title     VARCHAR(150) NOT NULL
);

CREATE TABLE course_section (
    course_id  VARCHAR(10) NOT NULL REFERENCES course (course_id),
    section_no VARCHAR(10) NOT NULL,
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

-- Insert sample data
INSERT INTO department (dept_name) VALUES ('Computer Science');
INSERT INTO course VALUES ('ENPM818T', 1, 'Databases');
INSERT INTO course VALUES ('ENPM605',  1, 'Python for Robotics');
INSERT INTO course VALUES ('ENPM702',  1, 'Robot Programming');
INSERT INTO course_section VALUES ('ENPM818T', '0101');
INSERT INTO course_section VALUES ('ENPM605',  '0101');
INSERT INTO course_section VALUES ('ENPM702',  '0101');

INSERT INTO person (first_name, last_name) VALUES ('Alice', 'Johnson'); -- 1
INSERT INTO person (first_name, last_name) VALUES ('Bob',   'Smith');   -- 2
INSERT INTO person (first_name, last_name) VALUES ('Carol', 'Davis');   -- 3
INSERT INTO person (first_name, last_name) VALUES ('David', 'Lee');     -- 4
INSERT INTO person (first_name, last_name) VALUES ('Eve',   'Brown');   -- 5

INSERT INTO student VALUES (1, '117453210');
INSERT INTO student VALUES (2, '117453211');
INSERT INTO student VALUES (3, '117453212');
INSERT INTO student VALUES (4, '117453213');
INSERT INTO student VALUES (5, '117453214');

INSERT INTO enrollment VALUES (1, 'ENPM818T', '0101', 'A');
INSERT INTO enrollment VALUES (2, 'ENPM818T', '0101', 'B+');
INSERT INTO enrollment VALUES (3, 'ENPM605',  '0101', 'A-');
INSERT INTO enrollment VALUES (4, 'ENPM702',  '0101', 'B');
INSERT INTO enrollment VALUES (5, 'ENPM818T', '0101', 'A');

-- Confirm five rows exist
SELECT * FROM enrollment;

-- --------------------------------------------------------
-- DELETE: remove specific rows
-- --------------------------------------------------------
DELETE FROM enrollment
    WHERE student_person_id IN (1, 2);

-- Confirm three rows remain
SELECT * FROM enrollment;

-- --------------------------------------------------------
-- TRUNCATE: remove all rows, keep structure
-- --------------------------------------------------------
TRUNCATE TABLE enrollment;

-- Confirm zero rows; table still exists
SELECT * FROM enrollment;
SELECT COUNT(*) FROM enrollment;

-- --------------------------------------------------------
-- TRUNCATE RESTART IDENTITY: reset the sequence too
-- --------------------------------------------------------
-- Re-insert to demonstrate sequence reset
INSERT INTO enrollment VALUES (3, 'ENPM605', '0101', 'A-');
TRUNCATE TABLE enrollment RESTART IDENTITY;

-- --------------------------------------------------------
-- TRUNCATE CASCADE: also truncates referencing tables
-- Run \d+ enrollment first to see what references it
-- --------------------------------------------------------

-- --------------------------------------------------------
-- DROP: remove table entirely
-- --------------------------------------------------------
DROP TABLE enrollment;

-- Confirm it is gone
SELECT * FROM enrollment;
-- ERROR: relation "enrollment" does not exist

-- Safe drop: no error if already absent
DROP TABLE IF EXISTS enrollment;

-- --------------------------------------------------------
-- DROP CASCADE: removes dependent objects too
-- --------------------------------------------------------
DROP TABLE course_section;
DROP TABLE course;
DROP TABLE student;
DROP TABLE department;
DROP TABLE person;