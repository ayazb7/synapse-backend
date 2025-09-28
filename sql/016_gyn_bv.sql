/* ==== CONFIG: topic and page metadata ==== */
WITH cfg AS (
  SELECT
    '4ab0e2ab-cb7c-445f-b080-ae8335abe3d7'::uuid AS topic_id,
    'Bacterial vaginosis (BV)'::text AS page_title,
    'bacterial-vaginosis'::text AS page_slug,
    'Very common, non-inflammatory vaginal condition due to loss of protective Lactobacillus and overgrowth of anaerobes; not an STI but associated with sexual activity.'::text AS page_summary
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
  $$<p>Bacterial vaginosis (BV) is a very common, non-inflammatory condition of the vagina resulting from an imbalance of the normal vaginal flora.</p><p>It is characterised by a significant reduction in the number of protective <em>Lactobacillus</em> species and an overgrowth of various anaerobic bacteria (e.g., <em>Gardnerella vaginalis</em>, <em>Mycoplasma hominis</em>, <em>Prevotella</em> species). It is not considered a sexually transmitted infection (STI) in the traditional sense, but it is more common in sexually active women.</p>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'overview'
  RETURNING 1
),
b_patho AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The healthy vaginal ecosystem is typically dominated by hydrogen peroxide-producing <em>Lactobacillus</em> species, which maintain an acidic vaginal pH (3.5–4.5) by producing lactic acid from glycogen. This acidic environment inhibits the growth of most pathogenic bacteria.</p><h4>Normal Vaginal Flora</h4><ul><li>Dominated by <strong>Lactobacillus</strong> (produce lactic acid + H₂O₂).</li><li>Keeps pH acidic (<strong>3.5–4.5</strong>) → inhibits pathogens.</li></ul><h4>In Bacterial Vaginosis</h4><ul><li>↓ <strong>Lactobacillus</strong> → loss of acidic protection.</li><li>↑ <strong>Vaginal pH (&gt;4.5)</strong>.</li><li><strong>Overgrowth of anaerobes:</strong> e.g., <em>Gardnerella vaginalis</em>, <em>Mobiluncus</em>, <em>Prevotella</em>, <em>Bacteroides</em>, <em>Mycoplasma hominis</em>.</li><li><strong>Biofilm formation</strong> (esp. <em>Gardnerella</em>) → harder to clear.</li><li><strong>Volatile amines</strong> produced → characteristic <strong>fishy odour</strong>, stronger after sex or soap use.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'pathophysiology'
  RETURNING 1
),
b_epi AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>Epidemiology</strong></p><ul><li><strong>Most common cause</strong> of vaginal discharge in reproductive-age women.</li><li><strong>Prevalence:</strong> ~10–30% globally.</li><li>Less common postmenopause (unless on oestrogen or with past BV).</li></ul><p><strong>Risk Factors</strong></p><ul><li><strong>Sexual activity:</strong> new/multiple partners, same-sex partners, unprotected sex.</li><li><strong>Vaginal practices:</strong> douching, perfumed products.</li><li><strong>Contraception:</strong> copper IUD (possible risk), condoms protective.</li><li><strong>Smoking.</strong></li><li><strong>Deficiency of Lactobacillus</strong> (natural or acquired).</li><li><strong>Stress</strong> (possible trigger, not proven cause).</li><li><strong>Genetic predisposition</strong> in some women.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'epidemiology-risk-factors'
  RETURNING 1
),
b_clin AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>BV can be asymptomatic in up to 50% of affected women. When symptoms are present, they are often mild.</p><table><thead><tr><th>Category</th><th>Features</th></tr></thead><tbody><tr><td><strong>Typical Presentation</strong></td><td><ul><li>Vaginal discharge: thin, white/grey, homogeneous, coats vaginal walls.</li><li><strong>Fishy odour</strong> (especially after sex or soap use).</li><li>Usually <strong>no itching, irritation, or soreness</strong> (unlike candidiasis); mild symptoms possible.</li></ul></td></tr><tr><td><strong>Atypical Presentation</strong></td><td><ul><li>Mild dysuria or dyspareunia.</li><li>Recurrent episodes common.</li></ul></td></tr><tr><td><strong>Red Flag Symptoms</strong> (suggest other diagnoses)</td><td><ul><li>Thick, curdy “cottage cheese” discharge → <strong>Candidiasis</strong>.</li><li>Frothy, green-yellow discharge with severe itching/soreness → <strong>Trichomoniasis</strong>.</li><li>Abdominal pain, fever, deep dyspareunia → <strong>PID</strong>.</li><li>Intermenstrual or post-coital bleeding → consider <strong>malignancy/serious pathology</strong>.</li></ul></td></tr></tbody></table>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'clinical-features'
  RETURNING 1
),
b_inv AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>Diagnosis of bacterial vaginosis is typically made clinically based on symptoms and physical examination, often supported by simple in-clinic tests or laboratory investigations.</p><p><strong>Amsel’s Criteria (need ≥3 for diagnosis):</strong></p><ol><li>Thin, homogeneous grey-white discharge.</li><li>Vaginal <strong>pH &gt;4.5</strong>.</li><li><strong>Positive whiff test</strong> (fishy odour after adding KOH).</li><li><strong>Clue cells</strong> on microscopy (epithelial cells coated with bacteria).</li></ol><p><strong>Other tests:</strong></p><ul><li><strong>Gram stain (Nugent score):</strong> Lab gold standard, not routine in UK primary care.</li><li><strong>NAATs:</strong> Very sensitive, used in some specialist settings, not first-line.</li><li><strong>High vaginal swab (HVS):</strong> Not useful for BV diagnosis (since <em>Gardnerella</em> can be normal flora), but done if other infections suspected (e.g., candida, trichomonas).</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'investigations'
  RETURNING 1
),
b_mgmt AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p>The primary goals of BV management are to relieve symptoms, reduce the risk of complications, and restore the vaginal flora balance. Treatment is typically with antibiotics.</p><p><strong>Pharmacological Management</strong></p><ul><li><strong>First-line (symptomatic women):</strong><ul><li><strong>Metronidazole</strong><ul><li>Oral: <strong>400 mg BD for 5–7 days</strong> (most common).</li><li>Vaginal gel (0.75%): <strong>5 g daily × 5 days</strong>.</li></ul></li><li><strong>Clindamycin</strong> (if metronidazole not tolerated)<ul><li>Vaginal cream (2%): <strong>5 g nightly × 7 days</strong>.</li><li>Oral: <strong>300 mg BD × 7 days</strong> (less used, risk of <em>C. diff</em>).</li></ul></li></ul></li></ul><p><strong>Pregnancy</strong></p><ul><li>Treat <strong>symptomatic BV</strong> (risk of preterm labour/miscarriage).</li><li><strong>Oral metronidazole 400 mg BD × 5–7 days</strong> = preferred.</li><li>Topical metronidazole/clindamycin = alternatives.</li><li><strong>Do not treat asymptomatic BV routinely</strong>.</li></ul><p><strong>Recurrent BV</strong></p><ul><li>≥3 episodes/year.</li><li>Longer oral course (10–14 days) or oral + maintenance topical (e.g., gel/cream twice weekly × 4–6 months).</li><li>Consider GUM/gynae referral.</li></ul><p><strong>Non-Pharmacological Advice</strong></p><ul><li><strong>Avoid douching</strong> and perfumed soaps/products.</li><li><strong>No need to treat male partners</strong>; treat symptomatic female partners.</li><li><strong>Condom use</strong> may reduce recurrence.</li><li><strong>Avoid alcohol</strong> with metronidazole and for 48h after (disulfiram-like reaction).</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'management'
  RETURNING 1
),
b_comp AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>Higher risk of STIs:</strong> HIV, HSV, gonorrhoea, chlamydia; ↑ risk of HIV transmission.</p><ul><li><strong>Pelvic Inflammatory Disease (PID):</strong> Especially after gynaecological procedures (e.g., IUD, termination, HSG).</li><li><strong>Pregnancy complications:</strong><ul><li>Preterm labour/birth</li><li>Late miscarriage</li><li>PROM (premature rupture of membranes)</li><li>Chorioamnionitis</li><li>Postpartum endometritis</li></ul></li><li><strong>Procedure-related infections:</strong> After hysterectomy, caesarean, or IUD insertion.</li><li><strong>Psychological impact:</strong> Distress, embarrassment, reduced sexual confidence.</li></ul>$$,
  '{}'::jsonb
  FROM sections s WHERE s.anchor_slug = 'complications'
  RETURNING 1
),
b_prog AS (
  INSERT INTO textbook_blocks (section_id, block_type, position, content, data)
  SELECT s.id, 'markdown'::textbook_block_type, 1,
  $$<p><strong>Treatment response:</strong> Usually good — symptoms resolve within days of antibiotics.</p><p><strong>Recurrence:</strong> Common problem.<ul><li>~50% recur within 6–12 months.</li><li>Up to 80% within 2 years.</li></ul></p><p><strong>Why recurrence happens:</strong><ul><li>Failure to restore <strong>Lactobacillus</strong> flora.</li><li>Ongoing risk factors (e.g., douching, new/unprotected partners).</li><li><strong>Biofilm formation</strong> by BV bacteria.</li><li>Genetic predisposition.</li></ul></p><p><strong>Long-term outlook:</strong> Often chronic and relapsing. May need repeated or maintenance therapy. Untreated/recurrent BV → ↑ risk of complications (STIs, PID, pregnancy issues).</p>$$,
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
      ('NICE-CKS-BV'::text, 'NICE CKS: Bacterial vaginosis — management'::text, 'website'::citation_type, NULL::text, 2024::integer, 'NICE'::text, 'https://cks.nice.org.uk/topics/bacterial-vaginosis/management/'::text, NULL::date, NULL::text, 1),
      ('NHSAAA-BV'::text, 'NHSAAA Medicines: Bacterial vaginosis'::text, 'website'::citation_type, NULL::text, 2024::integer, 'NHS Ayrshire & Arran'::text, 'https://aaamedicines.org.uk/guidelines/infections/bacterial-vaginosis/'::text, NULL::date, NULL::text, 2),
      ('BASHH-2012-BV'::text, 'BASHH National Guideline for Bacterial Vaginosis (2012)'::text, 'guideline'::citation_type, NULL::text, 2012::integer, 'BASHH'::text, 'https://www.bashhguidelines.org/media/1041/bv-2012.pdf'::text, NULL::date, NULL::text, 3),
      ('NOTTS-APC-BV'::text, 'Nottinghamshire APC: Bacterial vaginosis antibiotic prescribing guide'::text, 'website'::citation_type, NULL::text, 2022::integer, 'Notts APC'::text, 'https://www.nottsapc.nhs.uk/media/whlp2non/bacterial-vaginosis.pdf'::text, NULL::date, NULL::text, 4),
      ('PJ-2023-BV'::text, 'The Pharmaceutical Journal (2023): Bacterial vaginosis — diagnosis and management'::text, 'website'::citation_type, NULL::text, 2023::integer, 'The Pharmaceutical Journal'::text, 'https://pharmaceutical-journal.com/article/ld/bacterial-vaginosis-diagnosis-and-management'::text, NULL::date, NULL::text, 5),
      ('BMJ-BP-VAGINITIS'::text, 'BMJ Best Practice: Vaginitis — overview and management'::text, 'website'::citation_type, NULL::text, 2024::integer, 'BMJ'::text, 'https://bestpractice.bmj.com/topics/en-gb/75'::text, NULL::date, NULL::text, 6),
      ('PMC-2023-BV'::text, 'PMC Review (2023): Approaches to treatment and prevention of bacterial vaginosis'::text, 'website'::citation_type, NULL::text, 2023::integer, 'PMC'::text, 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10264601/'::text, NULL::date, NULL::text, 7)
  ) AS v(citation_key, label, source_type, authors, year, publisher, url, accessed_on, raw_citation, position)
  RETURNING 1
),

/* ==== INSERT TAGS ==== */
tags AS (
  INSERT INTO textbook_page_tags (page_id, tag)
  SELECT (SELECT id FROM pid), 'bacterial vaginosis'
  UNION ALL SELECT (SELECT id FROM pid), 'BV'
  UNION ALL SELECT (SELECT id FROM pid), 'gynaecology'
  UNION ALL SELECT (SELECT id FROM pid), 'vaginal discharge'
  UNION ALL SELECT (SELECT id FROM pid), 'vaginitis'
  UNION ALL SELECT (SELECT id FROM pid), 'Lactobacillus'
  UNION ALL SELECT (SELECT id FROM pid), 'metronidazole'
  ON CONFLICT (page_id, tag) DO NOTHING
  RETURNING 1
)
SELECT 1;

COMMIT;