/* ==== DELETE TEXTBOOK CONTENT BY SUBTOPIC ==== */
WITH RECURSIVE cfg AS (
  SELECT
    /* Paste the root subtopic id here (replace NULL) */
    'NULL'::uuid AS subtopic_id
),
descendants AS (
  SELECT c.subtopic_id
  FROM cfg c
  WHERE c.subtopic_id IS NOT NULL
  UNION ALL
  SELECT s.id
  FROM subtopics s
  JOIN descendants d ON s.parent_subtopic_id = d.subtopic_id
),
page_ids AS (
  SELECT p.id AS page_id
  FROM textbook_pages p
  WHERE p.subtopic_id IN (SELECT subtopic_id FROM descendants)
),
section_ids AS (
  SELECT s.id AS section_id
  FROM textbook_sections s
  WHERE s.page_id IN (SELECT page_id FROM page_ids)
),
del_blocks AS (
  DELETE FROM textbook_blocks
  WHERE section_id IN (SELECT section_id FROM section_ids)
  RETURNING 1
),
del_sections AS (
  DELETE FROM textbook_sections
  WHERE page_id IN (SELECT page_id FROM page_ids)
  RETURNING 1
),
del_citations AS (
  DELETE FROM textbook_citations
  WHERE page_id IN (SELECT page_id FROM page_ids)
  RETURNING 1
),
del_tags AS (
  DELETE FROM textbook_page_tags
  WHERE page_id IN (SELECT page_id FROM page_ids)
  RETURNING 1
),
del_pages AS (
  DELETE FROM textbook_pages
  WHERE id IN (SELECT page_id FROM page_ids)
  RETURNING 1
)
SELECT 1;

COMMIT;


