/* ==== CONFIG: subtopic and page metadata ==== */
WITH cfg AS (
  SELECT
    -- Resolve subtopic id by slug for idempotency
    (SELECT id FROM subtopics WHERE slug = 'bradyarrhythmias' LIMIT 1)::uuid AS subtopic_id,
    'Bradyarrhythmias'::text AS page_title,
    'bradyarrhythmias'::text AS page_slug,
    'Overview, pathophysiology, epidemiology, clinical features, investigations, management and prognosis for bradyarrhythmias.'::text AS page_summary
),

/* ==== PRECHECK: skip if subtopic missing ==== */
guard AS (
  SELECT subtopic_id FROM cfg WHERE subtopic_id IS NOT NULL
),

/* ==== UPSERT PAGE (by subtopic_id) ==== */
page_upsert AS (
  INSERT INTO textbook_pages (subtopic_id, title, slug, summary, status)
  SELECT c.subtopic_id, c.page_title, c.page_slug, c.page_summary, 'published'::content_status
  FROM guard g
  JOIN cfg c ON c.subtopic_id = g.subtopic_id
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
  FROM guard g
  JOIN textbook_pages p ON p.subtopic_id = g.subtopic_id
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

/* ==== INSERT BLOCKS (markdown content) ==== */
b_overview AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Bradyarrhythmias are a group of cardiac arrhythmias characterized by a heart rate that is too slow, typically defined as a resting heart rate below 60 beats per minute (bpm). A slow heart rate can lead to symptoms if cardiac output is insufficient to meet the body's metabolic demands. Bradyarrhythmias can originate from dysfunction of the sinus node (the heart's natural pacemaker) or disturbances in atrioventricular (AV) conduction.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<h4>Normal Impulse Generation and Conduction</h4><p>SA node generates impulses → spreads through atria → AV node delays briefly → ventricles activated via His-Purkinje system → ventricular contraction.</p><h4>Sinus Bradycardia</h4><p><strong>Mechanism:</strong> SA node fires &lt;60 bpm; conduction pathway normal.</p><p><strong>Causes:</strong></p><ul><li>Increased vagal tone (athletes, sleep, vagal manoeuvres, carotid sinus hypersensitivity)</li><li>Drugs: beta-blockers, calcium channel blockers (diltiazem, verapamil), digoxin, amiodarone</li><li>Hypothyroidism, hypothermia, hyperkalaemia</li><li>Myocardial ischaemia/inferior MI</li><li>Sick sinus syndrome</li><li>Increased intracranial pressure</li></ul><h4>Atrioventricular (AV) Blocks</h4><p><strong>Mechanism:</strong> Impaired conduction from atria → ventricles through AV node or His-Purkinje system.</p><ul><li><strong>1st Degree AV Block:</strong> PR interval consistently prolonged, all impulses conducted (usually at AV node). Causes: increased vagal tone, drugs, AV nodal disease, inferior MI.</li><li><strong>2nd Degree AV Block – Mobitz Type I (Wenckebach):</strong> PR interval progressively lengthens → dropped QRS → repeats (usually at AV node). Causes: vagal tone, drugs, inferior MI. Often benign.</li><li><strong>2nd Degree AV Block – Mobitz Type II:</strong> Intermittent blocked impulses without prior PR lengthening (usually below AV node). Causes: structural disease, anterior MI, fibrosis. Higher risk of progressing to complete heart block.</li><li><strong>3rd Degree AV Block (Complete Heart Block):</strong> No conduction from atria to ventricles → atria and ventricles beat independently. Escape rhythm maintains ventricular rate (junctional or ventricular). Causes: structural heart disease, MI, Lenègre-Lev disease, congenital heart block, hyperkalaemia, drug toxicity.</li></ul><h4>Sick Sinus Syndrome (SSS)</h4><p><strong>Mechanism:</strong> Sinus node fails to generate or conduct impulses; may alternate bradycardia/tachycardia.</p><p><strong>Types:</strong></p><ul><li>Persistent sinus bradycardia</li><li>Sinus arrest or sinus exit block</li><li>Bradycardia-tachycardia syndrome (e.g., AF with slow ventricular response)</li></ul><p><strong>Causes:</strong> Age-related fibrosis, ischaemia, inflammation, drugs.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>General:</strong> Bradyarrhythmias are more common in older adults due to age-related degenerative changes in the cardiac conduction system.</p><p><strong>Sinus Bradycardia:</strong> Very common. Can be physiological (e.g., in highly trained athletes) or pathological.</p><p><strong>AV Blocks:</strong> Prevalence increases with age. 1st degree AV block is relatively common and often benign. 2nd and 3rd degree AV blocks are less common but more clinically significant.</p><p><strong>Sick Sinus Syndrome:</strong> The most common indication for permanent pacemaker implantation in the UK and Western countries. Prevalence increases sharply with age.</p><h4>Key Risk Factors</h4><ul><li>Age</li><li>Ischaemic heart disease (MI)</li><li>Cardiac structural disease</li><li>Medications (beta-blockers, CCBs, digoxin, amiodarone; TCA, lithium)</li><li>Electrolyte imbalance (especially hyperkalaemia)</li><li>Hypothyroidism</li><li>Increased vagal tone</li><li>Infections (myocarditis, Lyme disease)</li><li>Infiltrative disease (sarcoidosis, amyloidosis, haemochromatosis)</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<h4>Common Symptoms</h4><ul><li>Dizziness / lightheadedness</li><li>Syncope / pre-syncope</li><li>Fatigue / weakness</li><li>Dyspnoea on exertion</li><li>Chest pain (if IHD)</li><li>Palpitations</li><li>Confusion / memory lapses</li></ul><h4>Specific Clinical Patterns</h4><ul><li>Sinus Bradycardia: Often asymptomatic; fatigue if HR &lt;50 bpm.</li><li>1st Degree AV Block: Usually asymptomatic.</li><li>2nd Degree AV Block (Mobitz I): Often benign; mild symptoms.</li><li>2nd Degree AV Block (Mobitz II): Dizziness/syncope; risk of progression.</li><li>3rd Degree AV Block: Highly symptomatic; Stokes-Adams attacks.</li><li>Sick Sinus Syndrome: Tachy-brady with intermittent symptoms.</li></ul><h4>Signs</h4><ul><li>Pulse: rate &lt;60 bpm; rhythm may be regular/irregular</li><li>Blood pressure: normal or low</li><li>JVP: cannon A waves (3rd degree AV block)</li><li>Heart sounds: variable S1 (3rd degree AV block)</li><li>Signs of heart failure in severe cases</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<h4>Initial Assessment</h4><p><strong>12-lead ECG:</strong> Essential for diagnosis and classification.</p><ul><li>Sinus Bradycardia: sinus rhythm, rate &lt;60 bpm.</li><li>1st Degree AV Block: PR &gt;0.20 s, fixed, all conducted.</li><li>2nd Degree AV Block Mobitz I: Progressive PR lengthening → dropped QRS.</li><li>2nd Degree AV Block Mobitz II: Constant PR with intermittent block.</li><li>3rd Degree AV Block: AV dissociation, atrial rate &gt; ventricular rate.</li><li>SSS: sinus pauses, arrest/exit block, tachy-brady.</li></ul><h4>Blood Tests</h4><ul><li>U&amp;Es, creatinine</li><li>TFTs</li><li>Troponin if MI suspected</li><li>Drug levels (e.g., digoxin) if toxicity suspected</li></ul><h4>Further Investigations</h4><ul><li>Ambulatory ECG monitoring (Holter)</li><li>Implantable loop recorder (ILR)</li><li>Exercise stress test</li><li>Electrophysiology study (EPS)</li><li>Echocardiography</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<h4>Acute Management</h4><ul><li>Treat reversible causes (drugs, electrolytes, hypothyroidism, MI)</li><li><strong>Atropine IV</strong> first-line; then isoprenaline/adrenaline/dopamine infusions as needed</li><li>Temporary pacing: transcutaneous or transvenous if unstable</li></ul><h4>Long-term Management</h4><ul><li>Sinus bradycardia: address causes; pacemaker if persistent symptomatic</li><li>1st Degree AV Block: usually no treatment</li><li>2nd Degree AV Block (Mobitz I): often benign; treat cause</li><li>2nd Degree AV Block (Mobitz II): permanent pacemaker</li><li>3rd Degree AV Block: permanent pacemaker</li><li>SSS: pacemaker if symptomatic; enables rate/rhythm drugs for tachyarrhythmias</li></ul><h4>Permanent Pacemaker</h4><p>Indicated for symptomatic SA node dysfunction, Mobitz II, complete heart block, and other guideline-based indications.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<ul><li>Syncope / falls</li><li>Worsening heart failure</li><li>Myocardial ischaemia / angina</li><li>Sudden cardiac death (high-grade AV block, SSS)</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Prognosis varies by cause and type. Asymptomatic physiological bradycardia is benign. High-grade AV blocks and symptomatic SSS without pacing carry significant risk; permanent pacing improves symptoms and outcomes. In acute MI-related bradyarrhythmias, many resolve with treatment or temporary pacing.</p>$$,
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
      ('NICE-CKS-BREATHLESSNESS'::text, 'NICE CKS: Breathlessness - Cardiac causes'::text, 'website'::citation_type, NULL::text, 2024::integer, 'NICE'::text, 'https://cks.nice.org.uk/topics/breathlessness/diagnosis/cardiac-causes/'::text, NULL::date, NULL::text, 1),
      ('NICE-NG106'::text, 'NICE NG106: Chronic heart failure in adults'::text, 'guideline'::citation_type, NULL::text, 2018::integer, 'NICE'::text, 'https://www.nice.org.uk/guidance/ng106'::text, NULL::date, NULL::text, 2),
      ('NICE-NG185'::text, 'NICE NG185: Acute coronary syndromes'::text, 'guideline'::citation_type, NULL::text, 2021::integer, 'NICE'::text, 'https://www.nice.org.uk/guidance/ng185'::text, NULL::date, NULL::text, 3)
  ) AS v(citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  RETURNING 1
),

/* ==== INSERT TAGS ==== */
tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), 'bradyarrhythmias'
  UNION ALL SELECT (SELECT id FROM pid), 'arrhythmia'
  UNION ALL SELECT (SELECT id FROM pid), 'cardiology'
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1 FROM guard;

COMMIT;


