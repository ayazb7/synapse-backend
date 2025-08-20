alter table if exists specialties
  add column if not exists icon_name text,
  add column if not exists icon_color text,
  add column if not exists icon_bg_start text,
  add column if not exists icon_bg_end text;

create or replace function public.get_user_specialty_cards(p_user_id uuid)
returns table (
  specialty_id uuid,
  specialty_name text,
  specialty_slug text,
  icon_name text,
  icon_color text,
  icon_bg_start text,
  icon_bg_end text,
  total_questions integer,
  completed_questions integer,
  accuracy_pct numeric,
  avg_time_ms integer,
  last_studied timestamptz,
  key_topics text[]
) language sql stable security definer as $$
  with tq as (
    select t.specialty_id, count(q.id)::int as total_questions
    from topics t
    left join questions q on q.topic_id = t.id and q.is_active
    group by t.specialty_id
  ),
  att as (
    select t.specialty_id,
           count(distinct a.question_id)::int as completed_questions,
           count(*) filter (where a.is_correct)::int as correct,
           count(*)::int as attempts,
           avg(a.time_taken_ms)::int as avg_time_ms,
           max(a.attempted_at) as last_studied
    from user_question_attempts a
    join questions q on q.id = a.question_id
    join topics t on t.id = q.topic_id
    where a.user_id = p_user_id
    group by t.specialty_id
  ),
  top_topics as (
    -- choose up to 3 topic slugs per specialty by most attempts; fallback to alphabetical
    select x.specialty_id,
           array_agg(x.slug order by x.rank, x.slug) as key_topics
    from (
      select t.specialty_id, t.slug,
             row_number() over (partition by t.specialty_id order by coalesce(cnt,0) desc, t.slug asc) as rn,
             coalesce(cnt, 999999) as rank
      from topics t
      left join (
        select q.topic_id, count(*) as cnt
        from user_question_attempts a
        join questions q on q.id = a.question_id
        where a.user_id = p_user_id
        group by q.topic_id
      ) c on c.topic_id = t.id
    ) x
    where x.rn <= 3
    group by x.specialty_id
  )
  select s.id,
         s.name,
         s.slug,
         s.icon_name,
         s.icon_color,
         s.icon_bg_start,
         s.icon_bg_end,
         coalesce(tq.total_questions,0) as total_questions,
         coalesce(att.completed_questions,0) as completed_questions,
         round(100.0 * coalesce(att.correct,0) / nullif(coalesce(att.attempts,0),0), 2) as accuracy_pct,
         att.avg_time_ms,
         att.last_studied,
         coalesce(tt.key_topics, '{}') as key_topics
  from specialties s
  left join tq on tq.specialty_id = s.id
  left join att on att.specialty_id = s.id
  left join top_topics tt on tt.specialty_id = s.id
  order by s.name;
$$;

-- Example seed for Cardiology icon (Lucide Heart), with white icon over gradient D84B3D -> C83C64
-- Run this after your specialties are inserted
update specialties
set icon_name = 'LuHeart',
    icon_color = '#FFFFFF',
    icon_bg_start = '#D84B3D',
    icon_bg_end = '#C83C64'
where slug = 'cardiology';


