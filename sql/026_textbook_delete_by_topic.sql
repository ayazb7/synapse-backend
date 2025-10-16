/* ==== DELETE TEXTBOOK CONTENT BY TOPIC (INCLUDES ALL SUBTOPICS) ==== */
/* Usage: Set topic_id below, then run. */
WITH RECURSIVE cfg AS (
  SELECT
    /* Paste the topic id here (replace NULL) */
    NULL::uuid AS topic_id
),
roots AS (
  SELECT s.id AS subtopic_id
  FROM cfg c
  JOIN subtopics s ON s.topic_id = c.topic_id
  WHERE c.topic_id IS NOT NULL
),
descendants AS (
  SELECT r.subtopic_id
  FROM roots r
  UNION ALL
  SELECT s.id AS subtopic_id
  FROM subtopics s
  JOIN descendants d ON s.parent_subtopic_id = d.subtopic_id
),
page_ids AS (
  /* Pages by subtopics */
  SELECT p.id AS page_id
  FROM textbook_pages p
  WHERE p.subtopic_id IN (SELECT subtopic_id FROM descendants)
  UNION
  /* Back-compat: pages keyed directly by topic */
  SELECT p2.id AS page_id
  FROM cfg c
  JOIN textbook_pages p2 ON p2.topic_id = c.topic_id
  WHERE c.topic_id IS NOT NULL
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

