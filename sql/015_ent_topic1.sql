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
  ON CONFLICT (page_id, anchor_slug) 
  DO UPDATE SET
    title = EXCLUDED.title,
    section_type = EXCLUDED.section_type,
    position = EXCLUDED.position,
    updated_at = now()
  RETURNING id, title, anchor_slug
),

/* ==== INSERT BLOCKS (cast block_type explicitly) ==== */
b_overview AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>An acoustic neuroma, also known as a vestibular schwannoma, is a benign, slow-growing tumour arising from the Schwann cells of the vestibular nerve (part of the eighth cranial nerve). While benign, its location within the narrow confines of the cerebellopontine angle means that as it grows, it can compress adjacent structures, leading to a range of neurological symptoms, most commonly affecting hearing and balance, and leading to symptoms of tinnitus.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The most common site of origin is within the internal auditory canal, specifically at the transition zone between central myelin (oligodendrocytes) and peripheral myelin (Schwann cells), known as Obersteiner-Redlich zone. This is the point at which the nerve exits the brainstem. As the tumour grows, it can extend into the cerebellopontine angle, leading to compression of:</p><ul><li><strong>Cochlear nerve:</strong> Resulting in sensorineural hearing loss, tinnitus.</li><li><strong>Vestibular nerve:</strong> Causing balance disturbances, vertigo.</li><li><strong>Facial nerve (CN VII):</strong> Leading to facial weakness or numbness (less common in early stages due to its superior and anterior position relative to CN VIII).</li><li><strong>Trigeminal nerve (CN V):</strong> Causing facial numbness or pain (in larger tumours).</li><li><strong>Brainstem and cerebellum:</strong> In very large tumours, leading to hydrocephalus, ataxia, and other severe neurological deficits.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Acoustic neuromas are relatively rare tumours, accounting for approximately 8% of all intracranial tumours and 80-90% of cerebellopontine angle tumours.</p><ul><li><strong>Age:</strong> Most commonly diagnosed between 40 and 60 years of age.</li><li><strong>Sex:</strong> Slight female predominance reported in some studies.</li><li><strong>Laterality:</strong> Typically unilateral.</li></ul><p><strong>Risk Factors:</strong></p><ul><li><strong>Neurofibromatosis type 2 (NF2):</strong> The main risk factor. An autosomal dominant disorder causing bilateral vestibular schwannomas, often presenting earlier and linked with other CNS tumours. Unilateral tumours rarely relate to NF2 (&lt;5%).</li><li><strong>Ionising radiation:</strong> High-dose radiation to the head and neck may increase risk, though not definitively proven for sporadic cases.</li><li><strong>Other factors:</strong> Noise exposure, mobile phone use, and diet have been studied, but evidence is weak and inconclusive.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Symptoms are often insidious and progressive due to the slow growth of the tumour. The specific symptoms depend on the size and location of the tumour and the structures compressed.</p><p><strong>Common Presenting Symptoms:</strong></p><ul><li><strong>Unilateral progressive sensorineural hearing loss (SNHL):</strong> Most frequent initial symptom (&gt;90%). Usually gradual and asymmetric. Sudden SNHL is less common but should raise suspicion of acoustic neuroma.</li><li><strong>Tinnitus:</strong> Often unilateral, on the same side as hearing loss.</li><li><strong>Balance disturbance/Dizziness:</strong> Patients usually report unsteadiness or disequilibrium rather than true vertigo.</li><li><strong>Vertigo:</strong> Less common, may occur with rapid tumour growth or vestibular nerve irritation.</li></ul><p><strong>Less Common/Late Symptoms (Indicating Larger Tumour or Compression):</strong></p><ul><li><strong>Facial numbness or weakness:</strong> Due to trigeminal (CN V) or facial nerve (CN VII) involvement.</li><li><strong>Headache:</strong> From tumour mass effect or raised intracranial pressure.</li><li><strong>Diplopia, dysphagia, dysarthria:</strong> Rare, due to involvement of other cranial nerves.</li><li><strong>Hydrocephalus:</strong> In very large tumours causing raised intracranial pressure.</li><li><strong>Ataxia:</strong> From cerebellar compression.</li></ul><p><strong>Red Flags:</strong></p><ul><li>Unilateral progressive SNHL or tinnitus (especially pulsatile).</li><li>Unexplained facial numbness or weakness.</li><li>Persistent unexplained disequilibrium.</li><li>Symptoms of raised intracranial pressure (e.g., severe headache, nausea, vomiting)</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The primary investigation for suspected acoustic neuroma is imaging of the brain, specifically targeting the cerebellopontine angle and internal auditory canal.</p><p><strong>NICE Recommendations and General Approach:</strong></p><p>While NICE does not have a specific guideline for "Acoustic Neuroma" per se, guidance on hearing loss and neurological symptoms indirectly supports the diagnostic pathway. Referral pathways for hearing loss and neurological symptoms are crucial.</p><p><strong>Initial Assessment:</strong></p><ul><li><strong>Full Otological and Neurological Examination:</strong> Assess cranial nerve function (especially CN V, VII, VIII), cerebellar signs, and gait.</li><li><strong>Audiometry:</strong> Essential for any patient with unilateral hearing symptoms. A pure tone audiogram will typically show an asymmetrical sensorineural hearing loss, often more pronounced at higher frequencies. Speech discrimination scores may be disproportionately poor compared to pure tone thresholds (rollover phenomenon), although this is not pathognomonic.</li><li><strong>Auditory Brainstem Response (ABR) Audiometry:</strong> Can be used as a screening tool, especially if MRI is contraindicated or not readily available. A prolonged interaural latency difference (I-V interval) or absent waves indicate retrocochlear pathology. However, MRI is more sensitive and specific.</li></ul><p><strong>Definitive Imaging:</strong></p><ul><li><strong>Magnetic Resonance Imaging (MRI) with Gadolinium Contrast:</strong> This is the gold standard investigation.<ul><li><strong>Purpose:</strong> Provides high-resolution imaging of the internal auditory canal and cerebellopontine angle.</li><li><strong>Interpretation:</strong> Acoustic neuromas typically appear as well-circumscribed, intensely enhancing lesions arising from the vestibulocochlear nerve, extending from the internal auditory canal into the cerebellopontine angle. Small intracanalicular tumours can be identified.</li><li><strong>NICE implications:</strong> While not explicitly stating "MRI for suspected AN," NICE guidance on unilateral sensorineural hearing loss or unexplained neurological symptoms would lead to MRI of the brain. For example, the NICE guideline for Suspected neurological conditions: recognition and referral (NG12, last updated 2023) recommends considering urgent referral for neuroimaging for patients with new onset focal neurological deficit.</li></ul></li><li><strong>Contrast CT Scan:</strong> Not the preferred imaging modality for diagnosing acoustic neuromas as it has poor soft tissue resolution compared to MRI. However, it may be used in emergencies (e.g., acute hydrocephalus) or if MRI is contraindicated. It can show bony erosion of the internal auditory canal or signs of hydrocephalus.</li></ul><p>Note: Initial assessments are completed by the GP. Acoustic neuromas are <strong>benign tumors</strong>, so they <strong>do not automatically qualify for a 2-week cancer referral</strong>. However, should the GP suspect Acoustic Neuroma, the patient is referred to ENT or neuro-otology clinic, at which point further investigations are carried out.</p><p><strong>Genetic Testing:</strong></p><ul><li>Consider genetic testing for <em>NF2</em> gene mutation in patients with suspected or confirmed bilateral vestibular schwannomas, or if there is a strong family history of NF2.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<ol><li><strong>Observation (Watch-and-Wait):</strong><ul><li>Indicated for small, asymptomatic tumours, elderly/frail patients, good hearing preservation, or patient preference to defer treatment.</li><li>Regular MRI (every 6-12 months initially) and audiometry to monitor growth and hearing.</li><li>Conservative approach when risks of intervention outweigh benefits.</li></ul></li><li><strong>Stereotactic Radiosurgery (SRS) / Stereotactic Radiotherapy (SRT):</strong><ul><li>Focused radiation aiming to stop tumour growth, not removal.</li><li>Suitable for small to medium tumours (&lt;3 cm), non-surgical candidates, or residual tumours.</li><li>Advantages: Non-invasive, outpatient, lower facial nerve palsy risk.</li><li>Disadvantages: Tumour remains, hearing may decline, possible delayed nerve effects.</li></ul></li><li><strong>Microsurgical Excision:</strong><ul><li>Surgical tumour removal via craniotomy.</li><li>Approaches:<ul><li><em>Translabyrinthine</em> (sacrifices hearing, for non-functional hearing cases),</li><li><em>Retrosigmoid/Suboccipital</em> (possible hearing preservation),</li><li><em>Middle fossa</em> (small intracanalicular tumours, hearing preservation).</li></ul></li><li>Indications: Large tumours causing brainstem compression/hydrocephalus, symptomatic younger patients, failure of other treatments.</li><li>Advantages: Immediate decompression, pathological diagnosis, potential complete removal.</li><li>Disadvantages: Invasive, higher risk of facial palsy, CSF leak, hearing loss, longer recovery.</li></ul></li></ol><p><strong>Post-Management Care:</strong></p><ul><li>Regular MRI for tumour monitoring or recurrence.</li><li>Audiological assessment and hearing rehabilitation as needed.</li><li>Vestibular rehabilitation for balance problems.</li><li>Facial nerve management including physiotherapy and eye care.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>From the tumour:</strong></p><ul><li>Sensorineural hearing loss (often profound on the affected side).</li><li>Balance problems and chronic disequilibrium.</li><li>Facial nerve dysfunction (weakness or palsy).</li><li>Trigeminal nerve symptoms (facial numbness or pain).</li><li>Brainstem compression causing neurological deficits and hydrocephalus.</li><li>Raised intracranial pressure symptoms (headache, nausea, papilloedema).</li></ul><p><strong>From surgical treatment:</strong></p><ul><li>Facial nerve palsy (temporary or permanent).</li><li>Hearing loss, especially with certain surgical approaches.</li><li>Cerebrospinal fluid leak, increasing meningitis risk.</li><li>Meningitis, haemorrhage, stroke, and wound complications.</li><li>Persistent dizziness and headache.</li><li>Rarely, mortality.</li></ul><p><strong>From stereotactic radiosurgery:</strong></p><ul><li>Delayed facial nerve or trigeminal neuropathy.</li><li>Progressive hearing deterioration.</li><li>Radiation-induced tissue damage (necrosis, edema).</li><li>Very rare risk of secondary tumours.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The prognosis for patients with acoustic neuroma is generally good, as it is a benign tumour. However, the long-term quality of life can be significantly impacted by residual symptoms or treatment-related complications, particularly hearing loss and facial nerve dysfunction.</p><ul><li><strong>Life Expectancy:</strong> Acoustic neuromas are rarely life-threatening unless they grow to a very large size, causing severe brainstem compression or hydrocephalus without intervention. With appropriate management, life expectancy is generally unaffected.</li><li><strong>Tumour Control:</strong><ul><li><strong>Observation:</strong> Many small tumours grow very slowly or not at all. Up to 50% may not grow significantly over several years.</li><li><strong>Radiosurgery:</strong> Tumour control rates (defined as no growth or shrinkage) are very high, often exceeding 90-95% over 5-10 years.</li><li><strong>Microsurgery:</strong> Complete resection rates are high, but depend on tumour size and adherence to vital structures. Recurrence after complete resection is rare.</li></ul></li><li><strong>Functional Outcomes:</strong><ul><li><strong>Hearing:</strong> The most common long-term issue is unilateral hearing loss, which can range from mild to profound. Hearing preservation is a key goal in treatment planning but is not always achieved.</li><li><strong>Balance:</strong> Chronic disequilibrium is common even after treatment, requiring vestibular rehabilitation in some cases.</li><li><strong>Facial Nerve Function:</strong> A major concern, especially with surgery. Good outcomes are generally expected for small to medium tumours, but larger tumours pose a higher risk of permanent facial weakness.</li><li><strong>Quality of Life:</strong> Can be impacted by persistent symptoms (hearing loss, tinnitus, balance issues, facial dysfunction), psychological distress, and the need for ongoing surveillance.</li></ul></li></ul><p>Regular follow-up is essential to monitor for tumour recurrence, growth, or the development/progression of complications, allowing for timely intervention if needed.</p>$$,
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
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1;

COMMIT;