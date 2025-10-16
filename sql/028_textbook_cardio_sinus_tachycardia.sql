/* ==== CREATE/UPDATE TEXTBOOK PAGE FOR A SUBSUBTOPIC: SINUS TACHYCARDIA ==== */
WITH cfg AS (
  SELECT
    /* Sinus Tachycardia subtopic id */
    'b259a2ac-2a36-4b35-9bf6-89b0f97d2690'::uuid AS subtopic_id,
    'Sinus Tachycardia'::text AS page_title,
    'sinus-tachycardia'::text AS page_slug,
    'Sinus tachycardia is a sinus rhythm >100 bpm, usually a physiological response to stress or an indicator of underlying pathology rather than a primary electrical disorder.'::text AS page_summary
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

/* Blocks */
b_overview AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Sinus tachycardia is a physiological or pathological condition characterised by a sinus rhythm with a heart rate exceeding 100 beats per minute. Unlike other tachyarrhythmias, it is typically a normal response to physiological stress or an indicator of an underlying medical condition, rather than a primary electrical abnormality of the heart. The electrical impulse originates correctly from the sinoatrial (SA) node, and cardiac conduction through the atria and ventricles is normal.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Sinus tachycardia results from an <strong>increased rate of depolarisation of the sinoatrial (SA) node</strong>, the heart's natural pacemaker. This acceleration is usually a physiological response to increased metabolic demand, sympathetic nervous system activation, or decreased vagal tone.</p>
<ul>
  <li><strong>Physiological causes:</strong> Exercise, emotional stress, anxiety, pain, fever.</li>
  <li><strong>Pathological causes (underlying conditions):</strong>
    <ul>
      <li><strong>Hypovolaemia/Dehydration:</strong> Compensatory response to maintain cardiac output.</li>
      <li><strong>Anaemia:</strong> Compensatory response to increase oxygen delivery.</li>
      <li><strong>Hypoxia:</strong> Compensatory response to increase oxygen delivery (e.g., respiratory failure, carbon monoxide poisoning).</li>
      <li><strong>Hyperthyroidism (Thyrotoxicosis):</strong> Increased metabolic rate and direct cardiac stimulation.</li>
      <li><strong>Sepsis/Infection:</strong> Systemic inflammatory response.</li>
      <li><strong>Fever:</strong> Increased metabolic rate.</li>
      <li><strong>Pulmonary Embolism:</strong> Hypoxia and stress response.</li>
      <li><strong>Heart Failure:</strong> Compensatory mechanism to maintain cardiac output in the setting of reduced ejection fraction.</li>
      <li><strong>Drugs/Stimulants:</strong> Caffeine, nicotine, recreational drugs (e.g., cocaine, amphetamines), beta-agonists (e.g., salbutamol), atropine.</li>
    </ul>
  </li>
  <li><strong>Autonomic factors:</strong> ↑ sympathetic tone and/or ↓ vagal tone.</li>
  <li><strong>SA node:</strong> Normal pacemaking and AV conduction pathway preserved.</li>
  </ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Sinus tachycardia is an extremely common finding across all age groups. Its "risk factors" are essentially the underlying conditions or physiological states that precipitate it.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Symptoms are usually non-specific and relate to the rapid heart rate or the underlying cause.</p>
<ul>
  <li><strong>Symptoms:</strong> Palpitations, lightheadedness, mild dyspnoea, or symptoms of the underlying cause (e.g., fever, anxiety, shortness of breath).</li>
  <li><strong>Clinical signs:</strong> Rapid, regular pulse; signs of underlying cause (e.g., pallor in anaemia, exophthalmos in thyrotoxicosis, pyrexia).</li>
  </ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Investigations focus on <strong>identifying the underlying cause</strong>; the tachycardia itself is rarely the primary problem.</p>
<ul>
  <li><strong>12-lead ECG:</strong> Confirm sinus rhythm and exclude other tachyarrhythmias (atrial flutter, SVT, VT).</li>
  <li><em>ECG findings:</em>
    <ul>
      <li>Normal P-wave morphology preceding every QRS complex.</li>
      <li>Normal PR interval.</li>
      <li>Normal QRS duration and morphology.</li>
      <li>Regular rhythm.</li>
      <li>Heart rate &gt;100 bpm.</li>
    </ul>
  </li>
  <li><strong>Full blood count (FBC):</strong> Anaemia or infection.</li>
  <li><strong>Urea and electrolytes (U&amp;Es):</strong> Dehydration or electrolyte disturbance.</li>
  <li><strong>Thyroid function tests (TFTs):</strong> Exclude hyperthyroidism.</li>
  <li><strong>CRP/Procalcitonin &amp; blood cultures:</strong> If infection/sepsis suspected.</li>
  <li><strong>Chest X-ray:</strong> Pulmonary causes (pneumonia, pulmonary oedema).</li>
  <li><strong>Echocardiogram (TTE):</strong> If structural heart disease or heart failure suspected.</li>
  <li><strong>Consider D-dimer/CTPA:</strong> If pulmonary embolism is a possibility.</li>
  </ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The cornerstone is to <strong>identify and treat the underlying cause</strong>. Direct rate control is seldom required unless symptoms are severe or there is coexisting heart disease.</p>
<ul>
  <li><strong>Address the cause:</strong>
    <ul>
      <li>Rehydration for hypovolaemia/dehydration.</li>
      <li>Transfusion for severe anaemia when indicated.</li>
      <li>Antipyretics for fever; antibiotics for infection.</li>
      <li>Treat hyperthyroidism.</li>
      <li>Optimise heart failure or respiratory disease.</li>
      <li>Withdraw/reduce causative drugs or stimulants.</li>
    </ul>
  </li>
  <li><strong>Rate control (selected cases):</strong>
    <ul>
      <li><strong>Beta-blockers (e.g., bisoprolol):</strong> Consider if distressing symptoms or where rapid rate may worsen ischaemia/heart failure with preserved EF. Typical oral dose: 2.5–5 mg once daily; individualise to patient and indication.</li>
      <li><strong>Ivabradine:</strong> Consider for inappropriate sinus tachycardia (diagnosis of exclusion) or in selected heart failure patients.</li>
    </ul>
  </li>
  </ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Sinus tachycardia rarely causes direct complications. Potential issues arise mainly when rates are very high and sustained in patients with significant underlying cardiac disease (e.g., precipitation or worsening of myocardial ischaemia or heart failure).</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Prognosis is generally excellent, with resolution once the underlying cause is treated. Sinus tachycardia is usually a sign of physiological stress or another condition rather than a primary life-threatening arrhythmia.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'prognosis'
  RETURNING 1
),

/* Citations */
cits AS (
  INSERT INTO textbook_citations
    (page_id, section_id, citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  SELECT p.id, NULL::uuid, v.citation_key, v.label, v.source_type, v.authors, v.year, v.publisher, v.url, v.accessed_on, v.raw_citation, v.position
  FROM pid p
  CROSS JOIN (
    VALUES
      ('BNF-ARR'::text, 'NICE BNF: Treatment Summary — Arrhythmias'::text, 'website'::citation_type, NULL::text, NULL::integer, 'NICE/BNF'::text, 'https://bnf.nice.org.uk/treatment-summaries/arrhythmias/'::text, NULL::date, NULL::text, 1)
  ) AS v(citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  ON CONFLICT DO NOTHING
  RETURNING 1
),

/* Tags */
tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), v.tag
  FROM (VALUES
    ('cardiology'::text),
    ('arrhythmias'::text),
    ('tachyarrhythmias'::text),
    ('sinus tachycardia'::text)
  ) AS v(tag)
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1;

COMMIT;


