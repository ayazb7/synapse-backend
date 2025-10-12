-- Add hierarchical relationships to subtopics

-- 1) Add parent_subtopic_id to allow nested subtopics
alter table public.subtopics
  add column if not exists parent_subtopic_id uuid null;

alter table public.subtopics
  add constraint subtopics_parent_fkey foreign key (parent_subtopic_id) references public.subtopics (id) on delete cascade;

create index if not exists subtopics_parent_idx on public.subtopics using btree (parent_subtopic_id) TABLESPACE pg_default;

-- 2) Validation trigger: ensure parent is within the same topic and prevent cycles
create or replace function public.validate_subtopic_parent()
returns trigger as $$
declare
  parent_topic_id uuid;
  cycle_found boolean;
begin
  if NEW.parent_subtopic_id is null then
    return NEW;
  end if;

  -- Parent must exist and be within the same topic
  select topic_id into parent_topic_id from public.subtopics where id = NEW.parent_subtopic_id;
  if parent_topic_id is null then
    raise exception 'Parent subtopic % does not exist', NEW.parent_subtopic_id using errcode = '23503';
  end if;
  if parent_topic_id <> NEW.topic_id then
    raise exception 'Parent subtopic must belong to the same topic' using errcode = '23514';
  end if;

  -- Prevent cycles: ensure NEW is not an ancestor of its parent
  with recursive ancestors as (
    select id, parent_subtopic_id from public.subtopics where id = NEW.parent_subtopic_id
    union all
    select s.id, s.parent_subtopic_id
    from public.subtopics s
    join ancestors a on s.id = a.parent_subtopic_id
  )
  select exists(select 1 from ancestors where id = NEW.id) into cycle_found;

  if cycle_found then
    raise exception 'Cyclic subtopic hierarchy is not allowed' using errcode = '23514';
  end if;

  return NEW;
end;
$$ language plpgsql;

drop trigger if exists trg_subtopics_parent_validate on public.subtopics;
create trigger trg_subtopics_parent_validate
before insert or update of parent_subtopic_id, topic_id on public.subtopics
for each row execute function public.validate_subtopic_parent();


