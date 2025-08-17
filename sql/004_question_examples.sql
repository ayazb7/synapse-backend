-- 1) Specialty + Topic
WITH s AS (
  INSERT INTO specialties (name, slug)
  VALUES ('Cardiology', 'cardiology')
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id
)
INSERT INTO topics (specialty_id, name, slug, description)
SELECT s.id, 'Acute Coronary Syndrome', 'acute-coronary-syndrome',
       'Diagnosis and management of ACS including STEMI and NSTEMI.'
FROM s
ON CONFLICT (specialty_id, slug) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description;

-- 2) Q1 (MCQ): Initial investigation in suspected ACS
WITH t AS (
  SELECT id AS topic_id FROM topics
  WHERE slug = 'acute-coronary-syndrome' LIMIT 1
),
q AS (
  INSERT INTO questions
    (topic_id, type, stem, explanation_l1, explanation_l2, difficulty, is_active)
  SELECT
    t.topic_id,
    'MCQ',
    'A 58-year-old man presents with 30 minutes of central crushing chest pain and diaphoresis. What is the single most appropriate initial investigation?',
    'Do an ECG early; it changes immediate management (e.g., PPCI for STEMI).',
    'NICE CG95 recommends recording a 12-lead ECG within 10 minutes of arrival for suspected ACS.',
    2, true
  FROM t
  ON CONFLICT DO NOTHING
  RETURNING id
)
INSERT INTO mcq_options (question_id, label, body, is_correct)
SELECT id, 'A', '12-lead ECG', true  FROM q UNION ALL
SELECT id, 'B', 'High-sensitivity troponin', false FROM q UNION ALL
SELECT id, 'C', 'Chest X-ray', false FROM q UNION ALL
SELECT id, 'D', 'D-dimer', false FROM q;

-- 3) Q2 (MCQ): Loading antiplatelet in suspected ACS
WITH t AS (
  SELECT id AS topic_id FROM topics
  WHERE slug = 'acute-coronary-syndrome' LIMIT 1
),
q AS (
  INSERT INTO questions
    (topic_id, type, stem, explanation_l1, explanation_l2, difficulty, is_active)
  SELECT
    t.topic_id,
    'MCQ',
    'A 67-year-old with suspected NSTEMI arrives in the ED. Which is the most appropriate immediate antiplatelet loading dose?',
    'Give aspirin early unless contraindicated.',
    'Typical UK practice: aspirin 300 mg (chewed or dispersed) as a loading dose.',
    2, true
  FROM t
  ON CONFLICT DO NOTHING
  RETURNING id
)
INSERT INTO mcq_options (question_id, label, body, is_correct)
SELECT id, 'A', 'Aspirin 300 mg', true  FROM q UNION ALL
SELECT id, 'B', 'Clopidogrel 300 mg only', false FROM q UNION ALL
SELECT id, 'C', 'Warfarin 10 mg', false FROM q UNION ALL
SELECT id, 'D', 'Alteplase 50 mg', false FROM q;

-- 4) Q3 (SAQ): Most specific biomarker
WITH t AS (
  SELECT id AS topic_id FROM topics
  WHERE slug = 'acute-coronary-syndrome' LIMIT 1
),
q AS (
  INSERT INTO questions
    (topic_id, type, stem, explanation_l1, explanation_l2, difficulty, is_active)
  SELECT
    t.topic_id,
    'SAQ',
    'Name the most specific blood biomarker for myocardial injury.',
    'Troponin (I or T) is highly specific for myocardial necrosis.',
    'Interpret in clinical context and with serial testing for rise/fall.',
    1, true
  FROM t
  ON CONFLICT DO NOTHING
  RETURNING id
)
-- Accept multiple phrasings; case-insensitive contains/regex
INSERT INTO saq_answer_keys (question_id, match_type, pattern, case_sensitive, weight)
SELECT id, 'contains'::saq_match_type, 'troponin', false, 1.0 FROM q UNION ALL
SELECT id, 'contains'::saq_match_type, 'troponin I', false, 1.0 FROM q UNION ALL
SELECT id, 'contains'::saq_match_type, 'troponin T', false, 1.0 FROM q;

-- 5) Q4 (MCQ): Infer culprit artery from inferior STEMI
WITH t AS (
  SELECT id AS topic_id FROM topics
  WHERE slug = 'acute-coronary-syndrome' LIMIT 1
),
q AS (
  INSERT INTO questions
    (topic_id, type, stem, explanation_l1, explanation_l2, difficulty, is_active)
  SELECT
    t.topic_id,
    'MCQ',
    'ECG shows ST elevation in leads II, III, and aVF. Which coronary artery is most commonly the culprit?',
    'Inferior STEMI usually involves the RCA.',
    'Inferior MI: RCA > LCx depending on dominance; look for RV involvement.',
    3, true
  FROM t
  ON CONFLICT DO NOTHING
  RETURNING id
)
INSERT INTO mcq_options (question_id, label, body, is_correct)
SELECT id, 'A', 'Left anterior descending (LAD)', false FROM q UNION ALL
SELECT id, 'B', 'Right coronary artery (RCA)', true  FROM q UNION ALL
SELECT id, 'C', 'Left circumflex (LCx)', false FROM q UNION ALL
SELECT id, 'D', 'Left main stem', false FROM q;

-- 6) Q5 (SAQ): Aspirin loading dose
WITH t AS (
  SELECT id AS topic_id FROM topics
  WHERE slug = 'acute-coronary-syndrome' LIMIT 1
),
q AS (
  INSERT INTO questions
    (topic_id, type, stem, explanation_l1, explanation_l2, difficulty, is_active)
  SELECT
    t.topic_id,
    'SAQ',
    'State the recommended initial loading dose of aspirin in suspected ACS (if not contraindicated).',
    'Loading with aspirin reduces mortality; give early.',
    'Common UK recommendation: 300 mg chewed or dispersed, followed by maintenance dosing.',
    1, true
  FROM t
  ON CONFLICT DO NOTHING
  RETURNING id
)
-- Accept answers that include “300” and optionally “mg”
INSERT INTO saq_answer_keys (question_id, match_type, pattern, case_sensitive, weight)
SELECT id, 'regex'::saq_match_type, '(^|\\D)300(\\s*)mg?(\\D|$)', false, 1.0 FROM q UNION ALL
SELECT id, 'contains'::saq_match_type, '300', false, 0.9 FROM q;
