/* ==== CROUP — FULL REBUILD USING EXISTING CONTENT (colorectal template) ==== */
WITH cfg AS (
  /* Croup topic UUID auto-found from topics_rows.csv */
  SELECT
    'b60ef3f0-7f11-44e1-a1da-447ea364e97d'::uuid AS topic_id
),

/* ----- Locate page ----- */
pid AS (
  SELECT p.id
  FROM textbook_pages p
  JOIN cfg c ON p.topic_id = c.topic_id
  LIMIT 1
),

/* ----- Capture existing sections/blocks BEFORE wipe ----- */
old_secs AS (
  SELECT s.id, s.anchor_slug
  FROM textbook_sections s
  WHERE s.page_id IN (SELECT id FROM pid)
),
old_blocks AS (
  SELECT s.anchor_slug,
         string_agg(b.content, E'\n' ORDER BY b.position) AS html
  FROM textbook_blocks b
  JOIN old_secs s ON s.id = b.section_id
  GROUP BY s.anchor_slug
),
old_cits AS (
  SELECT citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position
  FROM textbook_citations
  WHERE page_id IN (SELECT id FROM pid)
),
old_tags AS (
  SELECT tag
  FROM textbook_page_tags
  WHERE page_id IN (SELECT id FROM pid)
),

/* ----- Pull per-section raw HTML (may be NULL) ----- */
ov0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='overview'), '') AS html),
pa0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='pathophysiology'), '') AS html),
epi0  AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='epidemiology-risk-factors'), '') AS html),
cf0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='clinical-features'), '') AS html),
inv0  AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='investigations'), '') AS html),
mg0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='management'), '') AS html),
co0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='complications'), '') AS html),
pr0   AS (SELECT coalesce((SELECT html FROM old_blocks WHERE anchor_slug='prognosis'), '') AS html),

/* ----- Utility: remove a duplicate leading section heading & normalise <h5>→<h4> ----- */
ov1 AS (
  SELECT
    regexp_replace(
      regexp_replace((SELECT html FROM ov0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\1>\2</h4>', 'g'),
      '(?is)^\s*<h[1-6][^>]*>\s*(?:<strong>\s*)?overview\s*(?:</strong>)?\s*</h[1-6]>\s*', ''
    ) AS html
),
pa1 AS (
  SELECT
    regexp_replace(
      regexp_replace((SELECT html FROM pa0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\1>\2</h4>', 'g'),
      '(?is)^\s*<h[1-6][^>]*>\s*(?:<strong>\s*)?pathophysiology\s*(?:</strong>)?\s*</h[1-6]>\s*', ''
    ) AS html
),
epi1 AS (
  SELECT
    /* 1) Upgrade Risk factors heading; 2) remove any existing colgroup; 3) widen left column to 38% */
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace((SELECT html FROM epi0), '(?is)<h5\s*>\s*Risk\s*factors\s*</h5>', '<h4><strong>Risk factors</strong></h4>', 'g'),
          '(?is)<colgroup>.*?</colgroup>', '', 'g'
        ),
        '(?is)(<table[^>]*>)',
        E'\\1\n<colgroup><col style="width: 38%"><col style="width: 62%"></colgroup>',
        'g'
      ),
      '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g'
    ) AS html
),
/* ----- Clinical Features: build table + bold Red flags using existing content ----- */
cf_strip_h5 AS (
  SELECT
    regexp_replace((SELECT html FROM cf0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g') AS html
),
/* remove an existing "Clinical features" heading at the top (avoid duplication) */
cf2 AS (
  SELECT
    regexp_replace((SELECT html FROM cf_strip_h5),
                   '(?is)^\s*<h[1-6][^>]*>\s*(?:<strong>\s*)?clinical\s*features\s*(?:</strong>)?\s*</h[1-6]>\s*', '')
    AS html
),
/* Extract any existing Red flags list (if present) and remove it from the main body */
cf_redflags AS (
  SELECT
    /* UL after a "Red flag(s)" heading if present */
    (regexp_match((SELECT html FROM cf2),
      '(?is)<h[1-6][^>]*>\s*(?:<strong>\s*)?red\s*flags?\s*(?:</strong>)?\s*</h[1-6]>\s*(<ul>.*?</ul>)'
    ))[1] AS ul
),
/* Remove the whole Red flags heading + list from the body */
cf_body AS (
  SELECT
    regexp_replace(
      (SELECT html FROM cf2),
      '(?is)<h[1-6][^>]*>\s*(?:<strong>\s*)?red\s*flags?\s*(?:</strong>)?\s*</h[1-6]>\s*<ul>.*?</ul>\s*',
      '',
      'g'
    ) AS html
),
/* Build the new Clinical Features block with a table and a bold Red flags label; widen left column */
cf_final AS (
  SELECT
    format(
$$<h4>Clinical features</h4>
<table>
<colgroup><col style="width: 38%%"><col style="width: 62%%"></colgroup>
  <thead><tr><th>Category</th><th>Details</th></tr></thead>
  <tbody>
    <tr>
      <td><strong>Key signs &amp; symptoms</strong></td>
      <td>%s</td>
    </tr>
  </tbody>
</table>
<p><strong>Red flags</strong></p>
%s$$,
      NULLIF(trim((SELECT html FROM cf_body)), '')::text,
      coalesce((SELECT ul FROM cf_redflags), '<ul></ul>')
    ) AS html
),
inv1 AS (
  SELECT
    regexp_replace((SELECT html FROM inv0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g') AS html
),
mg1 AS (
  SELECT
    regexp_replace((SELECT html FROM mg0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g') AS html
),
co1 AS (
  SELECT
    regexp_replace((SELECT html FROM co0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g') AS html
),
pr1 AS (
  SELECT
    regexp_replace((SELECT html FROM pr0), '(?is)<h5([^>]*)>(.*?)</h5>', '<h4\\1>\\2</h4>', 'g') AS html
),

/* ===== Hard reset page content ===== */
del_tags AS (
  DELETE FROM textbook_page_tags WHERE page_id IN (SELECT id FROM pid)
),
del_cits AS (
  DELETE FROM textbook_citations WHERE page_id IN (SELECT id FROM pid)
),
del_secs AS (
  DELETE FROM textbook_sections WHERE page_id IN (SELECT id FROM pid)
),

/* ===== Recreate sections in colorectal order ===== */
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
  ON CONFLICT (page_id, anchor_slug) DO UPDATE
    SET title = EXCLUDED.title, section_type = EXCLUDED.section_type, position = EXCLUDED.position, updated_at = now()
  RETURNING id, anchor_slug
),

/* ===== Insert blocks from transformed existing content ===== */
b_ov AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM ov1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='overview'
  RETURNING 1
),
b_pa AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM pa1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM epi1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='epidemiology-risk-factors'
  RETURNING 1
),
b_cf AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM cf_final), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM inv1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='investigations'
  RETURNING 1
),
b_mg AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM mg1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='management'
  RETURNING 1
),
b_co AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM co1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='complications'
  RETURNING 1
),
b_pr AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown', 1, (SELECT html FROM pr1), '{}'::jsonb
  FROM sections s WHERE s.anchor_slug='prognosis'
  RETURNING 1
),

/* ===== Reinsert existing citations and tags (preserve order) ===== */
cits AS (
  INSERT INTO textbook_citations
    (page_id, section_id, citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  SELECT (SELECT id FROM pid), NULL::uuid,
         c.citation_key, c.label, c.source_type, c.authors, c.year, c.publisher, c.url, c.accessed_on, c.raw_citation, c.position
  FROM old_cits c
  RETURNING 1
),
tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), t.tag
  FROM old_tags t
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1;

COMMIT;
