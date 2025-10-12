-- Create subtopics table and update textbook_pages to support subtopic pages

-- 1) Subtopics table
create table if not exists public.subtopics (
  id uuid not null default gen_random_uuid(),
  topic_id uuid not null,
  name text not null,
  slug text not null,
  description text null,
  created_at timestamp with time zone not null default now(),
  constraint subtopics_pkey primary key (id),
  constraint subtopics_topic_id_fkey foreign key (topic_id) references public.topics (id) on delete cascade,
  constraint subtopics_topic_id_name_key unique (topic_id, name),
  constraint subtopics_topic_id_slug_key unique (topic_id, slug)
) TABLESPACE pg_default;

create index if not exists subtopics_topic_idx on public.subtopics using btree (topic_id) TABLESPACE pg_default;

-- 2) textbook_pages: allow either topic_id OR subtopic_id (exactly one must be set)
-- Make topic_id nullable to allow subtopic-only pages
alter table public.textbook_pages
  alter column topic_id drop not null;

-- Add subtopic_id and constraints
alter table public.textbook_pages
  add column if not exists subtopic_id uuid null,
  add constraint textbook_pages_subtopic_id_fkey foreign key (subtopic_id) references public.subtopics (id) on delete cascade;

-- Ensure uniqueness when set
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'textbook_pages_subtopic_id_key'
  ) then
    alter table public.textbook_pages add constraint textbook_pages_subtopic_id_key unique (subtopic_id);
  end if;
end $$;

-- Add a CHECK to guarantee exactly one of topic_id or subtopic_id is set
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'textbook_pages_topic_or_subtopic_chk'
  ) then
    alter table public.textbook_pages
      add constraint textbook_pages_topic_or_subtopic_chk
      check (
        (topic_id is not null and subtopic_id is null)
        or (topic_id is null and subtopic_id is not null)
      );
  end if;
end $$;

-- Optional: helpful index for status filtering
create index if not exists textbook_pages_subtopic_idx on public.textbook_pages using btree (subtopic_id) TABLESPACE pg_default;


