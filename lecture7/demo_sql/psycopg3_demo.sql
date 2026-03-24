-- ============================================================
-- ENPM818T L7 -- psycopg3 Demo Verification Queries
-- Run these in DataGrip / psql AFTER running the corresponding
-- Python demo script to confirm expected database state.
-- ============================================================

-- ------------------------------------------------------------
-- Demo 8: Minimal working connection (extra/standalone_test.py)
-- After running the script, confirm one new connection appeared.
-- ------------------------------------------------------------

SELECT count(*) AS active_connections
FROM pg_stat_activity
WHERE datname = 'university_db';


-- ------------------------------------------------------------
-- Demo 9: Transactions in Python
-- (extra/demo_transaction.py)
-- The script runs an atomic enrollment:
--   UPDATE course_section SET capacity = capacity - 1 ...
--   INSERT INTO enrollment ...
-- Verify both rows were committed.
-- ------------------------------------------------------------

SELECT capacity
FROM course_section
WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 29 (decremented from 30)

SELECT student_person_id, course_id, section_no
FROM enrollment
WHERE student_person_id = 4 AND course_id = 'ENPM818T';
-- Expected: one row for student 4

-- Then the script retries with person_id = 999 (FK violation).
-- Confirm capacity was restored by the automatic ROLLBACK.
SELECT capacity
FROM course_section
WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: still 29 (the failing transaction rolled back)


-- ------------------------------------------------------------
-- Demo 10: EnrollmentService (extra/demo_enrollment_service.py)
-- The script sets capacity = 2 and calls enroll_student twice
-- to exhaust the section, then calls it a third time expecting
-- ValueError("Section is full").
-- Verify final state after running the script.
-- ------------------------------------------------------------

-- Set capacity to 2 before running the Python script
UPDATE course_section SET capacity = 2
WHERE course_id = 'ENPM818T' AND section_no = '0101';

-- After running demo_enrollment_service.py:
SELECT capacity
FROM course_section
WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 0 (two successful enrollments)

SELECT student_person_id, course_id, section_no
FROM enrollment
WHERE course_id = 'ENPM818T' AND section_no = '0101'
ORDER BY student_person_id;
-- Expected: the two students enrolled by the script are listed

-- Confirm the third call raised ValueError and no row was inserted
-- (row count should match the two successful enrollments only)
SELECT count(*)
FROM enrollment
WHERE course_id = 'ENPM818T' AND section_no = '0101';
-- Expected: 2


-- ------------------------------------------------------------
-- Reset capacity after psycopg3 demos
-- Run this before the next demo session.
-- ------------------------------------------------------------

UPDATE course_section SET capacity = 30
WHERE course_id = 'ENPM818T' AND section_no = '0101';

DELETE FROM enrollment
WHERE course_id = 'ENPM818T'
  AND student_person_id IN (
      SELECT student_person_id
      FROM enrollment
      WHERE course_id = 'ENPM818T'
        AND section_no = '0101'
        AND grade IS NULL
  );
