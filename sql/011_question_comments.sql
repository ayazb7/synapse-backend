-- Question comments for per-question discussion threads
create table if not exists public.question_comments (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  parent_id uuid null references public.question_comments(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
) tablespace pg_default;

-- Helpful indexes
create index if not exists question_comments_question_idx on public.question_comments using btree (question_id);
create index if not exists question_comments_user_idx on public.question_comments using btree (user_id);
create index if not exists question_comments_parent_idx on public.question_comments using btree (parent_id);
create index if not exists question_comments_created_idx on public.question_comments using btree (created_at desc);

-- Updated at trigger
create trigger trg_question_comments_updated_at before update on public.question_comments for each row execute function set_updated_at();


