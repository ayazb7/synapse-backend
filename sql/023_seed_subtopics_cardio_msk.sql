-- Seed subtopics and nested hierarchies for Cardiology and MSK
-- Idempotent inserts using ON CONFLICT (topic_id, slug)

-- Ensure unique constraint for idempotent upserts
create unique index if not exists subtopics_topic_slug_uidx on public.subtopics (topic_id, slug);

-- =========================
-- Cardiology: Arrhythmias
-- Topic ID from data: 8d53a3ac-322c-4cf0-b68d-bbc330f99528
do $$
declare
  t_arr uuid;
  p_tachy uuid;
begin
  select id into t_arr from public.topics where slug = 'arrhythmias';
  if t_arr is null then
    raise notice 'Topic arrhythmias not found, skipping';
  else
    -- Top-level subtopics
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_arr, 'Bradyarrhythmias', 'bradyarrhythmias', null),
      (t_arr, 'Tachyarrhythmias', 'tachyarrhythmias', null),
      (t_arr, 'Pulseless electrical activity', 'pulseless-electrical-activity', null),
      (t_arr, 'Cardiac arrest', 'cardiac-arrest', null),
      (t_arr, 'Sudden arrhythmic death syndrome', 'sudden-arrhythmic-death-syndrome', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Children under Tachyarrhythmias
    select id into p_tachy from public.subtopics where topic_id = t_arr and slug = 'tachyarrhythmias';

    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_arr, 'Sinus tachycardia', 'sinus-tachycardia', p_tachy),
      (t_arr, 'Supraventricular tachycardia', 'supraventricular-tachycardia', p_tachy),
      (t_arr, 'Atrial fibrillation', 'atrial-fibrillation', p_tachy),
      (t_arr, 'Atrial flutter', 'atrial-flutter', p_tachy),
      (t_arr, 'AVNRT (Atrioventricular Nodal Re-entrant Tachycardia)', 'avnrt', p_tachy),
      (t_arr, 'AVRT (Atrioventricular Re-entrant Tachycardia) - Wolff-Parkinson-White (WPW) syndrome', 'avrt-wpw', p_tachy),
      (t_arr, 'Ventricular tachycardia', 'ventricular-tachycardia', p_tachy),
      (t_arr, 'Ventricular fibrillation', 'ventricular-fibrillation', p_tachy),
      (t_arr, 'Torsades de Pointes (TdP)', 'torsades-de-pointes-tdp', p_tachy)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- =====================================
-- Cardiology: Valvular Heart Disease
-- Topic ID from data: c8623511-765e-448b-a833-12c61cacbeba
do $$
declare
  t_valv uuid;
  s_aortic uuid;
  s_mitral uuid;
  s_right uuid;
  s_tricuspid uuid;
  s_pulmonary uuid;
begin
  select id into t_valv from public.topics where slug = 'valvular-heart-disease';
  if t_valv is null then
    raise notice 'Topic valvular-heart-disease not found, skipping';
  else
    -- Top-level families
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Aortic valve disease', 'aortic-valve-disease', null),
      (t_valv, 'Mitral valve disease', 'mitral-valve-disease', null),
      (t_valv, 'Right heart valve disease', 'right-heart-valve-disease', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Fetch parent ids
    select id into s_aortic from public.subtopics where topic_id = t_valv and slug = 'aortic-valve-disease';
    select id into s_mitral from public.subtopics where topic_id = t_valv and slug = 'mitral-valve-disease';
    select id into s_right  from public.subtopics where topic_id = t_valv and slug = 'right-heart-valve-disease';

    -- Aortic children
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Aortic valve stenosis', 'aortic-valve-stenosis', s_aortic),
      (t_valv, 'Aortic valve regurgitation', 'aortic-valve-regurgitation', s_aortic)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Mitral children
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Mitral valve stenosis', 'mitral-valve-stenosis', s_mitral),
      (t_valv, 'Mitral valve regurgitation', 'mitral-valve-regurgitation', s_mitral),
      (t_valv, 'Mitral valve prolapse', 'mitral-valve-prolapse', s_mitral)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Right heart children: Tricuspid + Pulmonary
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Tricuspid valve disease', 'tricuspid-valve-disease', s_right),
      (t_valv, 'Pulmonary valve disease', 'pulmonary-valve-disease', s_right)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Fetch ids for deeper nesting
    select id into s_tricuspid from public.subtopics where topic_id = t_valv and slug = 'tricuspid-valve-disease';
    select id into s_pulmonary from public.subtopics where topic_id = t_valv and slug = 'pulmonary-valve-disease';

    -- Tricuspid children
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Tricuspid valve stenosis', 'tricuspid-valve-stenosis', s_tricuspid),
      (t_valv, 'Tricuspid valve regurgitation', 'tricuspid-valve-regurgitation', s_tricuspid)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    -- Pulmonary children
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_valv, 'Pulmonary valve stenosis', 'pulmonary-valve-stenosis', s_pulmonary),
      (t_valv, 'Pulmonary valve regurgitation', 'pulmonary-valve-regurgitation', s_pulmonary)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- ===============================================
-- Cardiology: Cardiomyopathies & Myocardial Disease
-- Topic ID from data: 58c348ca-13ef-41c8-a303-1ddcc5c02f6a
do $$
declare
  t_cm uuid;
  s_peri uuid;
begin
  select id into t_cm from public.topics where slug = 'cardiomyopathies-and-myocardial-disease';
  if t_cm is null then
    raise notice 'Topic cardiomyopathies-and-myocardial-disease not found, skipping';
  else
    -- Top-level subtopics
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_cm, 'Cardiomyopathy', 'cardiomyopathy', null),
      (t_cm, 'Myocarditis', 'myocarditis', null),
      (t_cm, 'Pericardial disease', 'pericardial-disease', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;

    select id into s_peri from public.subtopics where topic_id = t_cm and slug = 'pericardial-disease';

    -- Children under Pericardial disease
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_cm, 'Pericarditis', 'pericarditis', s_peri),
      (t_cm, 'Pericardial effusions & cardiac tamponade', 'pericardial-effusions-and-cardiac-tamponade', s_peri)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- ===============================================
-- Cardiology: Hypertension & Vascular Conditions
-- Topic ID from data: dafbde67-308f-45f3-be4b-61e1465d5b38
do $$
declare
  t_htn uuid;
begin
  select id into t_htn from public.topics where slug = 'hypertension-and-vascular-conditions';
  if t_htn is null then
    raise notice 'Topic hypertension-and-vascular-conditions not found, skipping';
  else
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_htn, 'Essential (Primary) Hypertension', 'essential-primary-hypertension', null),
      (t_htn, 'Secondary Hypertension', 'secondary-hypertension', null),
      (t_htn, 'Hypertensive Emergencies/Urgencies', 'hypertensive-emergencies-urgencies', null),
      (t_htn, 'Pulmonary Hypertension', 'pulmonary-hypertension', null),
      (t_htn, 'Aortic Aneurysms (Abdominal, Thoracic)', 'aortic-aneurysms-abdominal-thoracic', null),
      (t_htn, 'Aortic Dissection', 'aortic-dissection', null),
      (t_htn, 'Peripheral Arterial Disease (PAD)', 'peripheral-arterial-disease-pad', null),
      (t_htn, 'Arterial & Venous Ulcers', 'arterial-and-venous-ulcers', null),
      (t_htn, 'Arterial Thrombosis', 'arterial-thrombosis', null),
      (t_htn, 'Intestinal Ischaemia', 'intestinal-ischaemia', null),
      (t_htn, 'Deep Vein Thrombosis (DVT)', 'deep-vein-thrombosis-dvt', null),
      (t_htn, 'Pulmonary Embolism (PE)', 'pulmonary-embolism-pe', null),
      (t_htn, 'Vasculitis', 'vasculitis', null),
      (t_htn, 'Stroke and Transient Ischaemic Attack (TIA)', 'stroke-and-transient-ischaemic-attack-tia', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- =========================
-- MSK: Lower limb fractures
-- Topic ID from data: a26f6a6c-7cb3-4ef5-aa1e-df62ccd18e08
do $$
declare
  t_llf uuid;
begin
  select id into t_llf from public.topics where slug = 'lower-limb-fractures';
  if t_llf is null then
    raise notice 'Topic lower-limb-fractures not found, skipping';
  else
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_llf, 'Pelvic fracture', 'pelvic-fracture', null),
      (t_llf, 'Hip fracture', 'hip-fracture', null),
      (t_llf, 'Femur fracture', 'femur-fracture', null),
      (t_llf, 'Patellar fracture', 'patellar-fracture', null),
      (t_llf, 'Tibia & fibular fractures', 'tibia-and-fibular-fractures', null),
      (t_llf, 'Ankle fractures', 'ankle-fractures', null),
      (t_llf, 'Foot fractures', 'foot-fractures', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- =========================
-- MSK: Lower limb soft tissue injury
-- Topic ID from data: 2faf9359-a6fa-4de4-aa57-c426fbd7f47f
do $$
declare
  t_llsti uuid;
begin
  select id into t_llsti from public.topics where slug = 'lower-limb-soft-tissue-injury';
  if t_llsti is null then
    raise notice 'Topic lower-limb-soft-tissue-injury not found, skipping';
  else
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_llsti, 'Lower limb soft tissue injuries', 'lower-limb-soft-tissue-injuries', null),
      (t_llsti, 'Hip dislocation', 'hip-dislocation', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- =========================
-- MSK: Upper limb fractures
-- Topic ID from data: 5d790503-dbce-4a86-97a5-081b8acb4a6f
do $$
declare
  t_ulf uuid;
begin
  select id into t_ulf from public.topics where slug = 'upper-limb-fractures';
  if t_ulf is null then
    raise notice 'Topic upper-limb-fractures not found, skipping';
  else
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_ulf, 'Clavicle fracture', 'clavicle-fracture', null),
      (t_ulf, 'Scapula fracture', 'scapula-fracture', null),
      (t_ulf, 'Humerus fracture', 'humerus-fracture', null),
      (t_ulf, 'Radius fracture', 'radius-fracture', null),
      (t_ulf, 'Ulnar fractures', 'ulnar-fractures', null),
      (t_ulf, 'Wrist fractures', 'wrist-fractures', null),
      (t_ulf, 'Hand fractures', 'hand-fractures', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;

-- =========================
-- MSK: Upper limb soft tissue injury
-- Topic ID from data: 5bb4d776-2d19-4215-a911-a7efd02a183b
do $$
declare
  t_ulsti uuid;
begin
  select id into t_ulsti from public.topics where slug = 'upper-limb-soft-tissue-injury';
  if t_ulsti is null then
    raise notice 'Topic upper-limb-soft-tissue-injury not found, skipping';
  else
    insert into public.subtopics (topic_id, name, slug, parent_subtopic_id) values
      (t_ulsti, 'Upper limb soft tissue injuries', 'upper-limb-soft-tissue-injuries', null),
      (t_ulsti, 'Shoulder dislocation', 'shoulder-dislocation', null)
    on conflict (topic_id, slug) do update set
      name = excluded.name,
      parent_subtopic_id = excluded.parent_subtopic_id;
  end if;
end $$;


