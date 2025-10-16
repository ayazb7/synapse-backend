/* ==== CREATE/UPDATE TEXTBOOK PAGE FOR A SUBTOPIC ==== */
WITH cfg AS (
  SELECT
    'NULL'::uuid AS subtopic_id,
    'Page Title'::text AS page_title,
    'page-slug'::text AS page_slug,
    'Short page summary.'::text AS page_summary
),

page_upsert AS (
  INSERT INTO textbook_pages (subtopic_id, title, slug, summary, status)
  SELECT subtopic_id, page_title, page_slug, page_summary, 'published'::content_status
  FROM cfg
  ON CONFLICT (subtopic_id)
  DO UPDATE SET
    title = EXCLUDED.title,
    slug = EXCLUDED.slug,
    summary = EXCLUDED.summary,
    status = EXCLUDED.status,
    updated_at = now()
  RETURNING id
),
pid AS (
  SELECT id FROM page_upsert
  UNION ALL
  SELECT p.id
  FROM cfg c
  JOIN textbook_pages p ON p.subtopic_id = c.subtopic_id
  WHERE NOT EXISTS (SELECT 1 FROM page_upsert)
  LIMIT 1
),

del_tags AS (
  DELETE FROM textbook_page_tags WHERE page_id IN (SELECT id FROM pid)
),
del_cits AS (
  DELETE FROM textbook_citations WHERE page_id IN (SELECT id FROM pid)
),
del_secs AS (
  DELETE FROM textbook_sections WHERE page_id IN (SELECT id FROM pid)
),

sections AS (
  INSERT INTO textbook_sections (page_id, parent_section_id, title, anchor_slug, section_type, position)
  SELECT p.id, NULL::uuid, v.title, v.anchor_slug, v.section_type, v.position
  FROM pid p
  CROSS JOIN (
    VALUES
      ('Overview'::text, 'overview'::text, 'overview'::textbook_section_type, 1),
      ('Pathophysiology', 'pathophysiology', 'pathophysiology'::textbook_section_type, 2),
      ('Epidemiology & Risk Factors', 'epidemiology-risk-factors', 'epidemiology_risk_factors'::textbook_section_type, 3),
      ('Clinical Features', 'clinical-features', 'clinical_features'::textbook_section_type, 4),
      ('Investigations', 'investigations', 'investigations'::textbook_section_type, 5),
      ('Management', 'management', 'management'::textbook_section_type, 6),
      ('Complications', 'complications', 'complications'::textbook_section_type, 7),
      ('Prognosis', 'prognosis', 'prognosis'::textbook_section_type, 8)
  ) AS v(title, anchor_slug, section_type, position)
  ON CONFLICT (page_id, anchor_slug) 
  DO UPDATE SET
    title = EXCLUDED.title,
    section_type = EXCLUDED.section_type,
    position = EXCLUDED.position,
    updated_at = now()
  RETURNING id, title, anchor_slug
),

b_overview AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Write overview]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Write key pathophysiology points]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Epidemiology and risk factors]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Clinical features]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Investigations]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Management]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Complications]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>[Prognosis]</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'prognosis'
  RETURNING 1
),

cits AS (
  INSERT INTO textbook_citations
    (page_id, section_id, citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  SELECT p.id, NULL::uuid, v.citation_key, v.label, v.source_type, v.authors, v.year, v.publisher, v.url, v.accessed_on, v.raw_citation, v.position
  FROM pid p
  CROSS JOIN (
    VALUES
      ('CIT-1'::text, 'Example source'::text, 'website'::citation_type, NULL::text, NULL::integer, NULL::text, NULL::text, NULL::date, NULL::text, 1)
  ) AS v(citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  ON CONFLICT DO NOTHING
  RETURNING 1
),

tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), 'example'
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1;

COMMIT;


