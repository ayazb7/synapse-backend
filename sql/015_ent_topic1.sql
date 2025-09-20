/* ==== CONFIG: topic and page metadata ==== */
WITH cfg AS (
  SELECT
    '0c9aaca3-731f-481c-b239-2c059e0b5df8'::uuid AS topic_id,
    'Acoustic Neuroma (Vestibular Schwannoma)'::text AS page_title,
    'acoustic-neuroma'::text AS page_slug,
    'Benign, slow‑growing Schwann cell tumour of the vestibular nerve in the internal auditory canal/cerebellopontine angle, typically causing progressive unilateral sensorineural hearing loss, balance disturbance and tinnitus.'::text AS page_summary
),

/* ==== UPSERT PAGE ==== */
page_upsert AS (
  INSERT INTO textbook_pages (topic_id, title, slug, summary, status)
  SELECT topic_id, page_title, page_slug, page_summary, 'published'::content_status
  FROM cfg
  ON CONFLICT (topic_id)
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
  JOIN textbook_pages p ON p.topic_id = c.topic_id
  WHERE NOT EXISTS (SELECT 1 FROM page_upsert)
  LIMIT 1
),

/* ==== CLEAR EXISTING CONTENT FOR THIS PAGE (safe re-run) ==== */
del_tags AS (
  DELETE FROM textbook_page_tags WHERE page_id IN (SELECT id FROM pid)
),
del_cits AS (
  DELETE FROM textbook_citations WHERE page_id IN (SELECT id FROM pid)
),
del_secs AS (
  DELETE FROM textbook_sections WHERE page_id IN (SELECT id FROM pid)
),

/* ==== INSERT SECTIONS (explicit casts via VALUES) ==== */
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
  RETURNING id, title, anchor_slug
),

/* ==== INSERT BLOCKS (cast block_type explicitly) ==== */
b_overview AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>An acoustic neuroma, also known as a vestibular schwannoma, is a benign, slow‑growing tumour arising from the Schwann cells of the vestibular nerve (part of the eighth cranial nerve). Because it develops within the narrow cerebellopontine angle and internal auditory canal, progressive growth can compress adjacent structures, most commonly affecting hearing and balance and causing tinnitus.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The typical origin is within the internal auditory canal at the Obersteiner–Redlich zone, where central myelin (oligodendrocytes) transitions to peripheral myelin (Schwann cells). As the tumour enlarges it may extend into the cerebellopontine angle and compress nearby structures:</p><ul><li><strong>Cochlear nerve</strong>: sensorineural hearing loss, tinnitus.</li><li><strong>Vestibular nerve</strong>: imbalance, vertigo.</li><li><strong>Facial nerve (CN VII)</strong>: facial weakness or numbness (less common early).</li><li><strong>Trigeminal nerve (CN V)</strong>: facial numbness or pain (in larger tumours).</li><li><strong>Brainstem/cerebellum</strong>: in very large tumours, hydrocephalus, ataxia and other deficits.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Accounts for ~8% of intracranial tumours and 80–90% of cerebellopontine angle tumours; usually unilateral, diagnosed most often at 40–60 years; slight female predominance in some series.</p><p><strong>Risk factors</strong>:</p><ul><li><strong>Neurofibromatosis type 2 (NF2)</strong>: bilateral vestibular schwannomas; earlier onset; &lt;5% unilateral cases related.</li><li><strong>Ionising radiation</strong>: high‑dose head/neck exposure (association not definitive for sporadic disease).</li><li><strong>Other</strong>: noise exposure, mobile phone use and diet have been studied but evidence is weak/inconclusive.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Symptoms are typically insidious and progressive.</p><p><strong>Common presenting symptoms</strong>:</p><ul><li>Unilateral progressive sensorineural hearing loss (&gt;90%); usually gradual and asymmetric; sudden loss less common but suspicious.</li><li>Tinnitus (often unilateral, ipsilateral to hearing loss).</li><li>Balance disturbance/disequilibrium more than true vertigo.</li><li>Vertigo (less common).</li></ul><p><strong>Less common/late symptoms</strong> (larger tumours/compression):</p><ul><li>Facial numbness or weakness (CN V/VII).</li><li>Headache.</li><li>Diplopia, dysphagia, dysarthria (rare).</li><li>Hydrocephalus; ataxia.</li></ul><p><strong>Red flags</strong>:</p><ul><li>Unilateral progressive SNHL or tinnitus (especially pulsatile).</li><li>Unexplained facial numbness or weakness.</li><li>Persistent unexplained disequilibrium.</li><li>Features of raised intracranial pressure (e.g. severe headache, nausea, vomiting).</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>Initial assessment</strong>:</p><ul><li>Full otological and neurological examination (cranial nerves, cerebellar signs, gait).</li><li>Audiometry: asymmetrical SNHL; speech discrimination may be disproportionately poor.</li><li>Auditory brainstem response (ABR): screening when MRI contraindicated/unavailable; MRI is more sensitive/specific.</li></ul><p><strong>Definitive imaging</strong>:</p><ul><li><strong>MRI brain with gadolinium</strong>: gold standard; high‑resolution IAC/CPA imaging; typically a well‑circumscribed, avidly enhancing lesion arising from CN VIII, often extending from the IAC into the CPA.</li><li><strong>CT with contrast</strong>: not preferred; consider in emergencies or if MRI contraindicated; may show IAC bony changes or hydrocephalus.</li></ul><p>Primary care assessment precedes specialist referral. Acoustic neuromas are benign and do not automatically trigger a 2‑week cancer pathway.</p><p><strong>Genetics</strong>: consider NF2 testing in bilateral disease or strong family history.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Choice depends on size, symptoms, hearing status, age/comorbidity and preference.</p><ol><li><strong>Observation (watch‑and‑wait)</strong>: small/asymptomatic, elderly/frail or good hearing; serial MRI (6–12‑monthly initially) and audiometry.</li><li><strong>Stereotactic radiosurgery/radiotherapy (SRS/SRT)</strong>: aims to halt growth; suitable for small–medium (&lt;3 cm), non‑surgical candidates or residual tumours. Advantages: non‑invasive, outpatient, lower facial nerve risk. Disadvantages: tumour persists; hearing may decline; delayed neuropathies possible.</li><li><strong>Microsurgical excision</strong>: translabyrinthine (non‑serviceable hearing), retrosigmoid/suboccipital (possible hearing preservation), or middle fossa (small intracanalicular, hearing preservation). Indications: large tumours with brainstem compression/hydrocephalus, younger symptomatic patients, or treatment failure. Advantages: immediate decompression, histology, potential cure. Disadvantages: invasive; risks include facial palsy, CSF leak, hearing loss, longer recovery.</li></ol><p><strong>Post‑management</strong>: MRI surveillance; audiology and hearing rehabilitation; vestibular rehabilitation; facial nerve care (physiotherapy, eye protection).</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>From the tumour</strong>:</p><ul><li>Sensorineural hearing loss.</li><li>Balance problems and chronic disequilibrium.</li><li>Facial nerve dysfunction.</li><li>Trigeminal nerve symptoms.</li><li>Brainstem compression with hydrocephalus.</li><li>Raised intracranial pressure symptoms.</li></ul><p><strong>From surgery</strong>:</p><ul><li>Facial nerve palsy.</li><li>Hearing loss.</li><li>CSF leak, meningitis, haemorrhage, stroke, wound complications.</li><li>Persistent dizziness and headache; rare mortality.</li></ul><p><strong>From stereotactic radiosurgery</strong>:</p><ul><li>Delayed facial/trigeminal neuropathy.</li><li>Progressive hearing decline.</li><li>Radiation‑induced tissue effects; very rare secondary tumours.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Generally favourable tumour control; quality of life may be affected by hearing/balance and facial nerve outcomes.</p><ul><li><strong>Observation</strong>: up to ~50% show little/no growth over several years.</li><li><strong>Radiosurgery</strong>: tumour control often &gt;90–95% at 5–10 years.</li><li><strong>Microsurgery</strong>: high complete resection rates; recurrence after complete excision is rare.</li><li><strong>Function</strong>: unilateral hearing loss common; balance problems may persist; facial nerve outcomes best with small–medium tumours.</li></ul><p>Long‑term follow‑up is essential to detect growth/recurrence or complications and to intervene promptly.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'prognosis'
  RETURNING 1
),

/* ==== INSERT CITATIONS ==== */
cits AS (
  INSERT INTO textbook_citations
    (page_id, section_id, citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  SELECT p.id, NULL::uuid, v.citation_key, v.label, v.source_type, v.authors, v.year, v.publisher, v.url, v.accessed_on, v.raw_citation, v.position
  FROM pid p
  CROSS JOIN (
    VALUES
      ('NHS-AN'::text, 'NHS: Acoustic neuroma (vestibular schwannoma)'::text, 'website'::citation_type, NULL::text, NULL::integer, NULL::text, 'https://www.nhs.uk/conditions/acoustic-neuroma/'::text, NULL::date, NULL::text, 1),
      ('PATIENT-AN'::text, 'Patient.info (Doctor): Acoustic neuromas'::text, 'website'::citation_type, NULL::text, NULL::integer, NULL::text, 'https://patient.info/doctor/acoustic-neuromas'::text, NULL::date, NULL::text, 2),
      ('NICE-NG98'::text, 'NICE Guideline NG98: Hearing loss in adults'::text, 'guideline'::citation_type, NULL::text, 2018::integer, 'NICE'::text, 'https://www.nice.org.uk/guidance/ng98'::text, NULL::date, NULL::text, 3),
      ('NICE-CKS-HL'::text, 'NICE CKS: Hearing loss in adults — causes'::text, 'website'::citation_type, NULL::text, NULL::integer, 'NICE'::text, 'https://cks.nice.org.uk/topics/hearing-loss-in-adults/background-information/causes/'::text, NULL::date, NULL::text, 4)
  ) AS v(citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  RETURNING 1
),

/* ==== INSERT TAGS ==== */
tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), 'acoustic neuroma'
  UNION ALL SELECT (SELECT id FROM pid), 'vestibular schwannoma'
  UNION ALL SELECT (SELECT id FROM pid), 'ENT'
  UNION ALL SELECT (SELECT id FROM pid), 'hearing loss'
  UNION ALL SELECT (SELECT id FROM pid), 'tinnitus'
  UNION ALL SELECT (SELECT id FROM pid), 'balance'
  UNION ALL SELECT (SELECT id FROM pid), 'NF2'
  RETURNING 1
)
SELECT 1;

COMMIT;