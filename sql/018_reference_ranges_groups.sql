-- Restructure reference ranges into groups and items
-- This migration creates two tables and migrates data from public.reference_ranges if present

create table if not exists public.reference_range_groups (
  id bigserial primary key,
  title text not null,
  group_order int not null default 0
);

create table if not exists public.reference_range_items (
  id bigserial primary key,
  group_id bigint not null references public.reference_range_groups(id) on delete cascade,
  analyte text not null,
  unit text,
  population text,
  value_text text not null,
  item_order int not null default 0
);

-- RLS
alter table public.reference_range_groups enable row level security;
alter table public.reference_range_items enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='reference_range_groups' and policyname='Allow read groups to authenticated'
  ) then
    create policy "Allow read groups to authenticated" on public.reference_range_groups for select to authenticated using (true);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='reference_range_items' and policyname='Allow read items to authenticated'
  ) then
    create policy "Allow read items to authenticated" on public.reference_range_items for select to authenticated using (true);
  end if;
end $$;

-- Try to migrate from existing flat table if present
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='reference_ranges') then
    -- Insert groups (distinct categories)
    insert into public.reference_range_groups (title, group_order)
    select r.category as title, min(coalesce(r.category_order, 0)) as group_order
    from public.reference_ranges r
    group by r.category
    on conflict do nothing;

    -- Insert items mapped to groups
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, r.analyte, r.unit, r.population, r.value_text, coalesce(r.item_order, 0)
    from public.reference_ranges r
    join public.reference_range_groups g on g.title = r.category
    on conflict do nothing;
  end if;
end $$;

-- Optional: seed if tables are still empty (fresh install)
do $$
declare
  cnt int;
begin
  select count(1) into cnt from public.reference_range_groups;
  if cnt = 0 then
    -- Minimal seed using the provided UKMLA structure
    -- Groups
    insert into public.reference_range_groups (title, group_order) values
    ('Haematology – Full Blood Count (FBC)', 1),
    ('Urea & Electrolytes (U&E / Renal Profile)', 2),
    ('Liver Function Tests (LFTs)', 3),
    ('Bone & Mineral Profile', 4),
    ('Endocrine & Diabetes', 5),
    ('Lipid Profile', 6),
    ('Cardiac Markers', 7),
    ('Pancreatic / GI', 8),
    ('Arterial/Venous Blood Gas (ABG/VBG)', 9),
    ('Iron Studies & Nutrition', 10),
    ('Inflammatory Markers', 11),
    ('Coagulation Profile', 12);

    -- Items (subset for brevity is not acceptable; include full list)
    -- Haematology – FBC
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Haematology – Full Blood Count (FBC)', 'Haemoglobin', 'g/L', 'male', '130–180', 1),
      ('Haematology – Full Blood Count (FBC)', 'Haemoglobin', 'g/L', 'female', '115–165', 1),
      ('Haematology – Full Blood Count (FBC)', 'Haematocrit (Hct)', null, 'male', '0.40–0.52', 2),
      ('Haematology – Full Blood Count (FBC)', 'Haematocrit (Hct)', null, 'female', '0.36–0.47', 2),
      ('Haematology – Full Blood Count (FBC)', 'Red Blood Cell Count', '×10¹²/L', 'male', '4.5–6.5', 3),
      ('Haematology – Full Blood Count (FBC)', 'Red Blood Cell Count', '×10¹²/L', 'female', '3.9–5.6', 3),
      ('Haematology – Full Blood Count (FBC)', 'Mean Corpuscular Volume (MCV)', 'fL', 'general', '80–96', 4),
      ('Haematology – Full Blood Count (FBC)', 'Mean Corpuscular Haemoglobin (MCH)', 'pg', 'general', '27–33', 5),
      ('Haematology – Full Blood Count (FBC)', 'White Cell Count (WCC)', '×10⁹/L', 'general', '4.0–11.0', 6),
      ('Haematology – Full Blood Count (FBC)', 'Neutrophils', '×10⁹/L', 'general', '2.0–7.5', 7),
      ('Haematology – Full Blood Count (FBC)', 'Lymphocytes', '×10⁹/L', 'general', '1.5–4.0', 8),
      ('Haematology – Full Blood Count (FBC)', 'Monocytes', '×10⁹/L', 'general', '0.2–0.8', 9),
      ('Haematology – Full Blood Count (FBC)', 'Eosinophils', '×10⁹/L', 'general', '0.0–0.4', 10),
      ('Haematology – Full Blood Count (FBC)', 'Basophils', '×10⁹/L', 'general', '0.0–0.1', 11),
      ('Haematology – Full Blood Count (FBC)', 'Platelets', '×10⁹/L', 'general', '150–400', 12)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- U&E / Renal Profile
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Sodium (Na⁺)', 'mmol/L', 'general', '135–145', 1),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Potassium (K⁺)', 'mmol/L', 'general', '3.5–5.0', 2),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Urea', 'mmol/L', 'general', '2.5–7.8', 3),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Creatinine', 'µmol/L', 'male', '60–110', 4),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Creatinine', 'µmol/L', 'female', '45–90', 4),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'eGFR', 'mL/min/1.73m²', 'general', '>90 (normal)', 5),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Bicarbonate (HCO₃⁻)', 'mmol/L', 'general', '22–29', 6),
      ('Urea & Electrolytes (U&E / Renal Profile)', 'Chloride (Cl⁻)', 'mmol/L', 'general', '98–107', 7)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- LFTs
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Liver Function Tests (LFTs)', 'Bilirubin (total)', 'µmol/L', 'general', '<21', 1),
      ('Liver Function Tests (LFTs)', 'ALT', 'IU/L', 'general', '<41', 2),
      ('Liver Function Tests (LFTs)', 'AST', 'IU/L', 'general', '<40', 3),
      ('Liver Function Tests (LFTs)', 'ALP', 'IU/L', 'general', '30–130', 4),
      ('Liver Function Tests (LFTs)', 'Gamma GT (GGT)', 'IU/L', 'male', '<55', 5),
      ('Liver Function Tests (LFTs)', 'Gamma GT (GGT)', 'IU/L', 'female', '<38', 5),
      ('Liver Function Tests (LFTs)', 'Albumin', 'g/L', 'general', '35–50', 6),
      ('Liver Function Tests (LFTs)', 'Total Protein', 'g/L', 'general', '60–80', 7)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Bone & Mineral Profile
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Bone & Mineral Profile', 'Calcium (corrected)', 'mmol/L', 'general', '2.2–2.6', 1),
      ('Bone & Mineral Profile', 'Phosphate', 'mmol/L', 'general', '0.8–1.5', 2),
      ('Bone & Mineral Profile', 'Magnesium', 'mmol/L', 'general', '0.7–1.0', 3),
      ('Bone & Mineral Profile', 'Vitamin D (25-OH)', 'nmol/L', 'general', '>50 (sufficient)', 4),
      ('Bone & Mineral Profile', 'Parathyroid Hormone (PTH)', 'pmol/L', 'general', '1.6–6.9', 5)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Endocrine & Diabetes
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Endocrine & Diabetes', 'Fasting Glucose', 'mmol/L', 'general', '3.5–5.4', 1),
      ('Endocrine & Diabetes', 'Random Glucose', 'mmol/L', 'general', '<7.8', 2),
      ('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'normal', '<42', 3),
      ('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'pre-diabetes', '42–47', 3),
      ('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'diabetes', '≥48', 3),
      ('Endocrine & Diabetes', 'TSH', 'mU/L', 'general', '0.4–4.0', 4),
      ('Endocrine & Diabetes', 'Free T4', 'pmol/L', 'general', '9–25', 5),
      ('Endocrine & Diabetes', 'Free T3', 'pmol/L', 'general', '3.5–7.8', 6),
      ('Endocrine & Diabetes', 'Cortisol (9am)', 'nmol/L', 'general', '200–700', 7),
      ('Endocrine & Diabetes', 'ACTH', 'ng/L', 'general', '10–50', 8),
      ('Endocrine & Diabetes', 'Prolactin', 'mIU/L', 'male', '<450', 9),
      ('Endocrine & Diabetes', 'Prolactin', 'mIU/L', 'female', '<500', 9)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Lipid Profile
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Lipid Profile', 'Total Cholesterol', 'mmol/L', 'general', '<5.0', 1),
      ('Lipid Profile', 'HDL', 'mmol/L', 'male', '>1.0', 2),
      ('Lipid Profile', 'HDL', 'mmol/L', 'female', '>1.2', 2),
      ('Lipid Profile', 'LDL', 'mmol/L', 'general', '<3.0', 3),
      ('Lipid Profile', 'Triglycerides', 'mmol/L', 'general', '<1.7', 4),
      ('Lipid Profile', 'Cholesterol:HDL ratio', null, 'general', '<4.5', 5)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Cardiac Markers
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Cardiac Markers', 'Troponin T (hs-cTnT)', 'ng/L', 'general', '<14 (assay-dependent)', 1),
      ('Cardiac Markers', 'BNP', 'pg/mL', 'normal', '<100 (normal)', 2),
      ('Cardiac Markers', 'BNP', 'pg/mL', 'suggestive of HF', '>400 suggests HF', 2),
      ('Cardiac Markers', 'CK (Creatine Kinase)', 'U/L', 'male', '40–320', 3),
      ('Cardiac Markers', 'CK (Creatine Kinase)', 'U/L', 'female', '25–200', 3),
      ('Cardiac Markers', 'LDH', 'U/L', 'general', '125–220', 4)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Pancreatic / GI
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Pancreatic / GI', 'Amylase', 'U/L', 'general', '30–110', 1),
      ('Pancreatic / GI', 'Lipase', 'U/L', 'general', '<60', 2)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- ABG/VBG
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'pH', null, 'general', '7.35–7.45', 1),
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'PaO₂', 'kPa', 'on air', '10–13', 2),
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'PaCO₂', 'kPa', 'general', '4.7–6.0', 3),
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'HCO₃⁻', 'mmol/L', 'general', '22–29', 4),
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'Base excess', 'mmol/L', 'general', '–2 to +2', 5),
      ('Arterial/Venous Blood Gas (ABG/VBG)', 'Lactate', 'mmol/L', 'general', '0.5–2.2', 6)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Iron Studies & Nutrition
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Iron Studies & Nutrition', 'Ferritin', 'µg/L', 'male', '30–400', 1),
      ('Iron Studies & Nutrition', 'Ferritin', 'µg/L', 'female', '15–150', 1),
      ('Iron Studies & Nutrition', 'Iron', 'µmol/L', 'general', '10–30', 2),
      ('Iron Studies & Nutrition', 'TIBC', 'µmol/L', 'general', '45–72', 3),
      ('Iron Studies & Nutrition', 'Transferrin saturation', '%', 'general', '20–50', 4),
      ('Iron Studies & Nutrition', 'Vitamin B12', 'ng/L', 'general', '160–925', 5),
      ('Iron Studies & Nutrition', 'Folate', 'µg/L', 'general', '>3', 6)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Inflammatory Markers
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Inflammatory Markers', 'CRP', 'mg/L', 'general', '<5', 1),
      ('Inflammatory Markers', 'ESR', 'mm/hr', 'male', '<15', 2),
      ('Inflammatory Markers', 'ESR', 'mm/hr', 'female', '<20', 2)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;

    -- Coagulation Profile
    insert into public.reference_range_items (group_id, analyte, unit, population, value_text, item_order)
    select g.id, v.analyte, v.unit, v.population, v.value_text, v.item_order from (
      values
      ('Coagulation Profile', 'PT', 's', 'general', '11–14', 1),
      ('Coagulation Profile', 'INR', null, 'general', '0.8–1.2 (therapeutic: 2.0–3.0; higher for mechanical valves)', 2),
      ('Coagulation Profile', 'aPTT', 's', 'general', '25–35', 3),
      ('Coagulation Profile', 'Fibrinogen', 'g/L', 'general', '1.5–4.0', 4),
      ('Coagulation Profile', 'D-dimer', 'µg/mL FEU', 'general', '<0.5', 5)
    ) as v(category, analyte, unit, population, value_text, item_order)
    join public.reference_range_groups g on g.title = v.category;
  end if;
end $$;

-- Optionally drop old flat table after migration
-- drop table if exists public.reference_ranges;


