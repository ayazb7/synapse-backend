-- Extend questions with richer explanations
alter table if exists public.questions
  add column if not exists explanation_eli5 text,
  add column if not exists explanation_l1_points text[], 
  add column if not exists detailed_context text,
  add column if not exists detailed_pathophysiology text;


