/* ==== DELETE TEXTBOOK CONTENT BY TOPIC ID ==== */
/* Set the topic_id below before running */
WITH cfg AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS topic_id
),

/* Identify the page for this topic */
pid AS (
  SELECT p.id
  FROM cfg c
  JOIN textbook_pages p ON p.topic_id = c.topic_id
  LIMIT 1
),

/* Collect section IDs for cascade deletion */
sec_ids AS (
  SELECT s.id
  FROM textbook_sections s
  WHERE s.page_id IN (SELECT id FROM pid)
),

/* Delete in dependency order */
del_blocks AS (
  DELETE FROM textbook_blocks
  WHERE section_id IN (SELECT id FROM sec_ids)
  RETURNING 1
),
del_sections AS (
  DELETE FROM textbook_sections
  WHERE page_id IN (SELECT id FROM pid)
  RETURNING 1
),
del_citations AS (
  DELETE FROM textbook_citations
  WHERE page_id IN (SELECT id FROM pid)
  RETURNING 1
),
del_tags AS (
  DELETE FROM textbook_page_tags
  WHERE page_id IN (SELECT id FROM pid)
  RETURNING 1
),
del_page AS (
  DELETE FROM textbook_pages
  WHERE id IN (SELECT id FROM pid)
  RETURNING 1
)
SELECT 1;

COMMIT;

