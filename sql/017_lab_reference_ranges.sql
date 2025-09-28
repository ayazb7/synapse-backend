-- Create a simple reference ranges table and seed with UKMLA ranges
-- Table is designed for read-mostly usage and easy grouping in the API

create table if not exists public.reference_ranges (
  id bigserial primary key,
  category text not null,
  analyte text not null,
  unit text,
  population text, -- e.g. 'male', 'female', 'general', 'normal', 'pre-diabetes', 'diabetes', etc.
  value_text text not null, -- human-readable range or threshold, e.g. '130–180 g/L' or '>90 mL/min/1.73m² (normal)'
  category_order int not null default 0,
  item_order int not null default 0
);

-- Optional: enable RLS and allow read for authenticated users
alter table public.reference_ranges enable row level security;
do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'reference_ranges' and policyname = 'Allow read to authenticated'
  ) then
    create policy "Allow read to authenticated" on public.reference_ranges for select to authenticated using (true);
  end if;
end $$;

-- Seed data
-- 1. Haematology – Full Blood Count (FBC)
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Haematology – Full Blood Count (FBC)', 'Haemoglobin', 'g/L', 'male', '130–180', 1, 1),
('Haematology – Full Blood Count (FBC)', 'Haemoglobin', 'g/L', 'female', '115–165', 1, 1),
('Haematology – Full Blood Count (FBC)', 'Haematocrit (Hct)', NULL, 'male', '0.40–0.52', 1, 2),
('Haematology – Full Blood Count (FBC)', 'Haematocrit (Hct)', NULL, 'female', '0.36–0.47', 1, 2),
('Haematology – Full Blood Count (FBC)', 'Red Blood Cell Count', '×10¹²/L', 'male', '4.5–6.5', 1, 3),
('Haematology – Full Blood Count (FBC)', 'Red Blood Cell Count', '×10¹²/L', 'female', '3.9–5.6', 1, 3),
('Haematology – Full Blood Count (FBC)', 'Mean Corpuscular Volume (MCV)', 'fL', 'general', '80–96', 1, 4),
('Haematology – Full Blood Count (FBC)', 'Mean Corpuscular Haemoglobin (MCH)', 'pg', 'general', '27–33', 1, 5),
('Haematology – Full Blood Count (FBC)', 'White Cell Count (WCC)', '×10⁹/L', 'general', '4.0–11.0', 1, 6),
('Haematology – Full Blood Count (FBC)', 'Neutrophils', '×10⁹/L', 'general', '2.0–7.5', 1, 7),
('Haematology – Full Blood Count (FBC)', 'Lymphocytes', '×10⁹/L', 'general', '1.5–4.0', 1, 8),
('Haematology – Full Blood Count (FBC)', 'Monocytes', '×10⁹/L', 'general', '0.2–0.8', 1, 9),
('Haematology – Full Blood Count (FBC)', 'Eosinophils', '×10⁹/L', 'general', '0.0–0.4', 1, 10),
('Haematology – Full Blood Count (FBC)', 'Basophils', '×10⁹/L', 'general', '0.0–0.1', 1, 11),
('Haematology – Full Blood Count (FBC)', 'Platelets', '×10⁹/L', 'general', '150–400', 1, 12);

-- 2. Urea & Electrolytes (U&E / Renal Profile)
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Urea & Electrolytes (U&E / Renal Profile)', 'Sodium (Na⁺)', 'mmol/L', 'general', '135–145', 2, 1),
('Urea & Electrolytes (U&E / Renal Profile)', 'Potassium (K⁺)', 'mmol/L', 'general', '3.5–5.0', 2, 2),
('Urea & Electrolytes (U&E / Renal Profile)', 'Urea', 'mmol/L', 'general', '2.5–7.8', 2, 3),
('Urea & Electrolytes (U&E / Renal Profile)', 'Creatinine', 'µmol/L', 'male', '60–110', 2, 4),
('Urea & Electrolytes (U&E / Renal Profile)', 'Creatinine', 'µmol/L', 'female', '45–90', 2, 4),
('Urea & Electrolytes (U&E / Renal Profile)', 'eGFR', 'mL/min/1.73m²', 'general', '>90 (normal)', 2, 5),
('Urea & Electrolytes (U&E / Renal Profile)', 'Bicarbonate (HCO₃⁻)', 'mmol/L', 'general', '22–29', 2, 6),
('Urea & Electrolytes (U&E / Renal Profile)', 'Chloride (Cl⁻)', 'mmol/L', 'general', '98–107', 2, 7);

-- 3. Liver Function Tests (LFTs)
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Liver Function Tests (LFTs)', 'Bilirubin (total)', 'µmol/L', 'general', '<21', 3, 1),
('Liver Function Tests (LFTs)', 'ALT', 'IU/L', 'general', '<41', 3, 2),
('Liver Function Tests (LFTs)', 'AST', 'IU/L', 'general', '<40', 3, 3),
('Liver Function Tests (LFTs)', 'ALP', 'IU/L', 'general', '30–130', 3, 4),
('Liver Function Tests (LFTs)', 'Gamma GT (GGT)', 'IU/L', 'male', '<55', 3, 5),
('Liver Function Tests (LFTs)', 'Gamma GT (GGT)', 'IU/L', 'female', '<38', 3, 5),
('Liver Function Tests (LFTs)', 'Albumin', 'g/L', 'general', '35–50', 3, 6),
('Liver Function Tests (LFTs)', 'Total Protein', 'g/L', 'general', '60–80', 3, 7);

-- 4. Bone & Mineral Profile
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Bone & Mineral Profile', 'Calcium (corrected)', 'mmol/L', 'general', '2.2–2.6', 4, 1),
('Bone & Mineral Profile', 'Phosphate', 'mmol/L', 'general', '0.8–1.5', 4, 2),
('Bone & Mineral Profile', 'Magnesium', 'mmol/L', 'general', '0.7–1.0', 4, 3),
('Bone & Mineral Profile', 'Vitamin D (25-OH)', 'nmol/L', 'general', '>50 (sufficient)', 4, 4),
('Bone & Mineral Profile', 'Parathyroid Hormone (PTH)', 'pmol/L', 'general', '1.6–6.9', 4, 5);

-- 5. Endocrine & Diabetes
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Endocrine & Diabetes', 'Fasting Glucose', 'mmol/L', 'general', '3.5–5.4', 5, 1),
('Endocrine & Diabetes', 'Random Glucose', 'mmol/L', 'general', '<7.8', 5, 2),
('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'normal', '<42', 5, 3),
('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'pre-diabetes', '42–47', 5, 3),
('Endocrine & Diabetes', 'HbA1c', 'mmol/mol', 'diabetes', '≥48', 5, 3),
('Endocrine & Diabetes', 'TSH', 'mU/L', 'general', '0.4–4.0', 5, 4),
('Endocrine & Diabetes', 'Free T4', 'pmol/L', 'general', '9–25', 5, 5),
('Endocrine & Diabetes', 'Free T3', 'pmol/L', 'general', '3.5–7.8', 5, 6),
('Endocrine & Diabetes', 'Cortisol (9am)', 'nmol/L', 'general', '200–700', 5, 7),
('Endocrine & Diabetes', 'ACTH', 'ng/L', 'general', '10–50', 5, 8),
('Endocrine & Diabetes', 'Prolactin', 'mIU/L', 'male', '<450', 5, 9),
('Endocrine & Diabetes', 'Prolactin', 'mIU/L', 'female', '<500', 5, 9);

-- 6. Lipid Profile
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Lipid Profile', 'Total Cholesterol', 'mmol/L', 'general', '<5.0', 6, 1),
('Lipid Profile', 'HDL', 'mmol/L', 'male', '>1.0', 6, 2),
('Lipid Profile', 'HDL', 'mmol/L', 'female', '>1.2', 6, 2),
('Lipid Profile', 'LDL', 'mmol/L', 'general', '<3.0', 6, 3),
('Lipid Profile', 'Triglycerides', 'mmol/L', 'general', '<1.7', 6, 4),
('Lipid Profile', 'Cholesterol:HDL ratio', NULL, 'general', '<4.5', 6, 5);

-- 7. Cardiac Markers
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Cardiac Markers', 'Troponin T (hs-cTnT)', 'ng/L', 'general', '<14 (assay-dependent)', 7, 1),
('Cardiac Markers', 'BNP', 'pg/mL', 'normal', '<100 (normal)', 7, 2),
('Cardiac Markers', 'BNP', 'pg/mL', 'suggestive of HF', '>400 suggests HF', 7, 2),
('Cardiac Markers', 'CK (Creatine Kinase)', 'U/L', 'male', '40–320', 7, 3),
('Cardiac Markers', 'CK (Creatine Kinase)', 'U/L', 'female', '25–200', 7, 3),
('Cardiac Markers', 'LDH', 'U/L', 'general', '125–220', 7, 4);

-- 8. Pancreatic / GI
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Pancreatic / GI', 'Amylase', 'U/L', 'general', '30–110', 8, 1),
('Pancreatic / GI', 'Lipase', 'U/L', 'general', '<60', 8, 2);

-- 9. Arterial/Venous Blood Gas (ABG/VBG)
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Arterial/Venous Blood Gas (ABG/VBG)', 'pH', NULL, 'general', '7.35–7.45', 9, 1),
('Arterial/Venous Blood Gas (ABG/VBG)', 'PaO₂', 'kPa', 'on air', '10–13', 9, 2),
('Arterial/Venous Blood Gas (ABG/VBG)', 'PaCO₂', 'kPa', 'general', '4.7–6.0', 9, 3),
('Arterial/Venous Blood Gas (ABG/VBG)', 'HCO₃⁻', 'mmol/L', 'general', '22–29', 9, 4),
('Arterial/Venous Blood Gas (ABG/VBG)', 'Base excess', 'mmol/L', 'general', '–2 to +2', 9, 5),
('Arterial/Venous Blood Gas (ABG/VBG)', 'Lactate', 'mmol/L', 'general', '0.5–2.2', 9, 6);

-- 10. Iron Studies & Nutrition
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Iron Studies & Nutrition', 'Ferritin', 'µg/L', 'male', '30–400', 10, 1),
('Iron Studies & Nutrition', 'Ferritin', 'µg/L', 'female', '15–150', 10, 1),
('Iron Studies & Nutrition', 'Iron', 'µmol/L', 'general', '10–30', 10, 2),
('Iron Studies & Nutrition', 'TIBC', 'µmol/L', 'general', '45–72', 10, 3),
('Iron Studies & Nutrition', 'Transferrin saturation', '%', 'general', '20–50', 10, 4),
('Iron Studies & Nutrition', 'Vitamin B12', 'ng/L', 'general', '160–925', 10, 5),
('Iron Studies & Nutrition', 'Folate', 'µg/L', 'general', '>3', 10, 6);

-- 11. Inflammatory Markers
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Inflammatory Markers', 'CRP', 'mg/L', 'general', '<5', 11, 1),
('Inflammatory Markers', 'ESR', 'mm/hr', 'male', '<15', 11, 2),
('Inflammatory Markers', 'ESR', 'mm/hr', 'female', '<20', 11, 2);

-- 12. Coagulation Profile
insert into public.reference_ranges (category, analyte, unit, population, value_text, category_order, item_order) values
('Coagulation Profile', 'PT', 's', 'general', '11–14', 12, 1),
('Coagulation Profile', 'INR', NULL, 'general', '0.8–1.2 (therapeutic: 2.0–3.0; higher for mechanical valves)', 12, 2),
('Coagulation Profile', 'aPTT', 's', 'general', '25–35', 12, 3),
('Coagulation Profile', 'Fibrinogen', 'g/L', 'general', '1.5–4.0', 12, 4),
('Coagulation Profile', 'D-dimer', 'µg/mL FEU', 'general', '<0.5', 12, 5);


