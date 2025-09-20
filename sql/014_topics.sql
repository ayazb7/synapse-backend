-- Enable useful extensions (safe if they already exist)
create extension if not exists unaccent;
create extension if not exists pgcrypto;

-- Helper to make URL-friendly slugs
create or replace function public.slugify(t text)
returns text
language sql
immutable
as $$
  select trim(both '-' from
         regexp_replace(
           regexp_replace(
             lower(unaccent(coalesce(t, ''))),
             '[^a-z0-9]+', '-', 'g'
           ),
           '-{2,}', '-', 'g'
         )
       );
$$;

do
$$
declare
  v_data jsonb := $json$
{
  "Acute & Emergency": [
    "Acid-Base Abnormality",
    "Anaphylaxis",
    "Compartment Syndrome",
    "Hyperthermia & Hypothermia"
  ],
  "Cancer": [
    "Basal Cell Carcinoma",
    "Bladder Cancer",
    "Brain Metastases",
    "Breast Cancer",
    "Cervical Cancer",
    "Colorectal Tumours",
    "Endometrial Cancer",
    "Gastric Cancer",
    "Hypercalcaemia of Malignancy",
    "Leukaemia",
    "Lung Cancer",
    "Lymphoma",
    "Malignant Melanoma",
    "Metastatic Disease",
    "Multiple Myeloma",
    "Oesophageal Cancer",
    "Ovarian Cancer",
    "Pancreatic Cancer",
    "Prostate Cancer",
    "Squamous Cell Carcinoma",
    "Testicular Cancer"
  ],
  "Cardiology": [
    "Ischaemic Heart Disease",
    "Heart Failure",
    "Arrhythmias",
    "Valvular Heart Disease",
    "Cardiomyopathies & Myocardial Disease",
    "Hypertension & Vascular Conditions",
    "Vasovagal Syncope"
  ],
  "Child Health (Paediatrics)": [
    "Biliary Atresia",
    "Developmental Delay",
    "Down’s Syndrome",
    "Epiglottitis",
    "Febrile Convulsion",
    "Henoch-Schonlein Purpura (HSP) / IgA Vasculitis",
    "Juvenile Idiopathic Arthritis",
    "Intussusception",
    "Kawasaki Disease",
    "Mesenteric Adenitis",
    "Muscular Dystrophies",
    "Necrotising Enterocolitis",
    "Pyloric Stenosis",
    "Rubella",
    "Malnutrition",
    "Non Accidental Injury"
  ],
  "Clinical Haematology": [
    "Anaemia",
    "Disseminated Intravascular Coagulation",
    "Haemochromatosis",
    "Haemoglobinopathies",
    "Haemophilia",
    "Hyposplenism / Splenectomy",
    "Myeloproliferative Disorders",
    "Pancytopenia",
    "Patient on Anticoagulant Therapy",
    "Patient on Antiplatelet Therapy",
    "Polycythaemia",
    "Sickle Cell Disease",
    "Transfusion Reactions"
  ],
  "Clinical Imaging": [
    "Spinal fractures",
    "Volvulus"
  ],
  "Dermatology": [
    "Acne Vulgaris",
    "Atopic Dermatitis / Eczema",
    "Contact Dermatitis",
    "Folliculitis",
    "Head Lice",
    "Impetigo",
    "Psoriasis",
    "Scabies",
    "Urticaria"
  ],
  "ENT": [
    "Acoustic Neuroma",
    "Benign Paroxysmal Positional Vertigo (BPPV)",
    "Epistaxis",
    "Ménière's Disease",
    "Otitis Externa",
    "Otitis Media",
    "Rhinosinusitis",
    "Tonsillitis"
  ],
  "GI Including Liver": [
    "Acute Cholangitis",
    "Acute Pancreatitis",
    "Alcoholic Hepatitis",
    "Ascites",
    "Acute Cholecystitis",
    "Cirrhosis",
    "Coeliac Disease",
    "Constipation",
    "Gallstones (Cholelithiasis) & Biliary Colic",
    "Gastritis",
    "Gastro-Oesophageal Reflux Disease",
    "Hepatitis",
    "Inflammatory Bowel Disease (IBD)",
    "Irritable Bowel Syndrome (IBS)",
    "Liver Failure",
    "Malabsorption",
    "Peptic Ulcer Disease (PUD)",
    "Vitamin B12 & Folate Deficiency"
  ],
  "GP & Primary Healthcare": [
    "Allergic Disorder",
    "Chronic Fatigue Syndrome",
    "Disease Prevention / Screening",
    "Menopause",
    "Migraine",
    "Tension Headache",
    "Trigeminal Neuralgia"
  ],
  "Infection": [
    "Brain abscess",
    "Candidiasis",
    "Cellulitis",
    "Conjunctivitis",
    "COVID-19",
    "Croup",
    "Cutaneous fungal infection",
    "Cutaneous warts",
    "Encephalitis",
    "Epididymitis and orchitis",
    "Herpes simplex virus",
    "Hospital Acquired Infections",
    "HIV",
    "Human Papilloma Virus Infection",
    "Infectious Colitis",
    "Infectious diarrhoea",
    "Infectious mononucleosis",
    "Influenza",
    "Lyme disease",
    "Malaria",
    "Measles",
    "Meningitis",
    "Mumps",
    "Necrotising fasciitis",
    "Notifiable diseases",
    "Periorbital and orbital cellulitis",
    "Sepsis",
    "Toxic shock syndrome",
    "Trichomonas Vaginalis",
    "Varicella Zoster",
    "Viral exanthema",
    "Viral gastroenteritis",
    "Viral hepatitides",
    "Whooping cough"
  ],
  "Medicine of Older Adults (Geriatrics)": [
    "Delirium",
    "Dementias",
    "Malnutrition",
    "Non-Accidental Injury",
    "Osteoporosis",
    "Parkinson’s disease",
    "Pressure ulcers",
    "Urinary Incontinence"
  ],
  "Mental Health": [
    "Acute Stress Disorder",
    "Anxiety disorder: Generalised",
    "Anxiety Disorder: Post-Traumatic Stress Disorder",
    "Anxiety: phobias",
    "Drug Overdose",
    "Anxiety: OCD",
    "Attention Deficit Hyperactivity Disorder",
    "Autism Spectrum Disorder",
    "Bipolar Affective Disorder",
    "Depression",
    "Eating Disorders",
    "Personality Disorder",
    "Schizophrenia",
    "Self Harm",
    "Somatisation",
    "Substance Use Disorder"
  ],
  "Metabolism & Endocrinology": [
    "Addison’s Disease",
    "Cushing’s Syndrome",
    "Diabetes in Pregnancy (Gestational & Pre-Existing)",
    "Diabetes Insipidus",
    "Diabetes Mellitus type 1 & 2",
    "Diabetic Ketoacidosis (DKA)",
    "Diabetic Nephropathy",
    "Diabetic Neuropathy",
    "Hyperlipidaemia",
    "Hyperosmolar Hyperglycaemic State",
    "Hyperparathyroidism",
    "Hypoglycaemia",
    "Hypoparathyroidism",
    "Hypothyroidism",
    "Obesity",
    "Pituitary Tumours",
    "Thyroid Eye Disease",
    "Thyroid Nodules",
    "Thyrotoxicosis"
  ],
  "MSK (Musculoskeletal)": [
    "Ankylosing Spondylitis",
    "Bursitis",
    "Crystal Arthropathy",
    "Fibromyalgia",
    "Lower limb fractures",
    "Lower limb soft tissue injury",
    "Osteoarthritis",
    "Osteomalacia",
    "Osteomyelitis",
    "Osteoporosis",
    "Pathological Fracture",
    "Polymyalgia Rheumatica",
    "Reactive Arthritis",
    "Rheumatoid Arthritis",
    "Septic Arthritis",
    "Systemic Lupus Erythematous",
    "Upper Limb Fractures",
    "Upper Limb Soft Tissue Injury"
  ],
  "Neurosciences": [
    "Bell’s Palsy",
    "Cerebral palsy",
    "Hypoxic-Ischaemic Encephalopathy (HIE)",
    "Epilepsy",
    "Extradural haemorrhage",
    "Multiple Sclerosis",
    "Myasthenia Gravis",
    "Motor neurone disease",
    "Peripheral nerve injuries",
    "Radiculopathies",
    "Raised Intracranial Pressure",
    "Spinal Cord Compression",
    "Spinal cord injury",
    "Subarachnoid haemorrhage",
    "Subdural haemorrhage",
    "Wernicke’s encephalopathy"
  ],
  "Obstetrics & Gynaecology": [
    "Bacterial Vaginosis",
    "Atrophic vaginitis",
    "Cervical screening programme",
    "Cord prolapse",
    "Ectopic pregnancy",
    "Endometriosis",
    "Fibroids",
    "Obesity and pregnancy",
    "Pelvic Inflammatory Disease",
    "Placenta Praevia",
    "Placental abruption",
    "Post-partum haemorrhage",
    "Termination of pregnancy",
    "Vasa praevia",
    "VTE in pregnancy"
  ],
  "Ophthalmology": [
    "Acute glaucoma",
    "Benign eyelid disorders",
    "Blepharitis",
    "Cataracts",
    "Central retinal artery occlusion",
    "Chronic glaucoma",
    "Infective keratitis",
    "Iritis",
    "Macular degeneration",
    "Optic neuritis",
    "Retinal detachment",
    "Scleritis",
    "Uveitis",
    "Visual field defects"
  ],
  "Palliative & End of Life Care": [
    "Multi organ dysfunction syndrome",
    "Perioperative medicine & anaesthesia",
    "Surgical site infection"
  ],
  "Renal & Urology": [
    "Acute Kidney Injury",
    "Benign Prostatic Hyperplasia",
    "Chronic Kidney Disease",
    "Dehydration",
    "Diabetes Insipidus",
    "Nephrotic Syndrome",
    "Urinary tract calculi",
    "Urinary Tract Infection",
    "Testicular Torsion"
  ],
  "Respiratory": [
    "Acute bronchitis",
    "Asbestos related lung disease",
    "Asthma",
    "Asthma-COPD overlap",
    "Bronchiectasis",
    "Bronchiolitis",
    "Chronic Obstructive Pulmonary Disease",
    "Cystic fibrosis",
    "Fibrotic lung disease",
    "Lower respiratory tract infection",
    "Obstructive sleep apnoea",
    "Occupational Lung Disease",
    "Pneumonia",
    "Pneumothorax",
    "Respiratory failure",
    "Sarcoidosis",
    "Tuberculosis",
    "Upper respiratory tract infection"
  ],
  "Sexual Health": [
    "Chlamydia",
    "Gonorrhoea",
    "Syphilis"
  ],
  "Surgery": [
    "Anal Fissure",
    "Appendicitis",
    "Breast Abscess",
    "Breast cyst",
    "Diverticular Disease",
    "Fibroadenomas",
    "Gastrointestinal Perforation",
    "Haemorrhoids (Piles)",
    "Hernias",
    "Hiatus Hernia",
    "Intestinal ischaemia",
    "Intestinal obstruction",
    "Perianal Abscesses & Fistulae",
    "Peritonitis",
    "Varicose veins"
  ],
  "All areas of clinical practice": [
    "Adverse drug effects"
  ]
}
$json$::jsonb;

begin
  -- 1) Insert any missing specialties (compare by LOWER(name))
  with src as (
    select key::text as name, public.slugify(key::text) as slug
    from jsonb_object_keys(v_data) as key
  ),
  to_insert as (
    select gen_random_uuid() as id, s.name, s.slug
    from src s
    left join specialties sp on lower(sp.name) = lower(s.name)
    where sp.id is null
  )
  insert into specialties (id, name, slug, created_at)
  select id, name, slug, now() from to_insert
  on conflict (slug) do nothing;

  -- 2) Insert any missing topics (compare by LOWER(name) within specialty)
    with pairs as (
    select
        kv.key::text                      as specialty_name,
        public.slugify(kv.key::text)      as specialty_slug,
        jsonb_array_elements_text(kv.value) as topic_name
    from jsonb_each(v_data) as kv(key, value)
    ),
    resolved as (
    select
        s.id                               as specialty_id,
        p.topic_name                       as topic_name,
        public.slugify(p.topic_name)       as topic_slug
    from pairs p
    join specialties s
        on s.slug = p.specialty_slug
        or lower(s.name) = lower(p.specialty_name)
    )
    insert into topics (id, specialty_id, name, slug, description, created_at)
    select
    gen_random_uuid(),
    r.specialty_id,
    r.topic_name,
    r.topic_slug,
    null,
    now()
    from (
    select distinct on (specialty_id, topic_slug)
            specialty_id, topic_name, topic_slug
    from resolved
    order by specialty_id, topic_slug, topic_name
    ) r
    on conflict do nothing;  

end;
$$ language plpgsql;
