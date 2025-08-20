-- Fix duplicate counting - count unique questions instead of attempts

-- Updated user totals function to count unique questions
create or replace function public.get_user_totals(p_user_id uuid)
returns table (
  total_answered integer,
  correct integer,
  accuracy_pct numeric,
  avg_time_ms integer,
  last_attempt_at timestamptz
) language sql stable security definer as $$
  with unique_questions as (
    select 
      question_id,
      bool_or(is_correct) as ever_correct,
      avg(time_taken_ms) as avg_time,
      max(attempted_at) as last_attempt
    from user_question_attempts
    where user_id = p_user_id
    group by question_id
  )
  select
    count(*)::int as total_answered,
    count(*) filter (where ever_correct)::int as correct,
    round(100.0 * count(*) filter (where ever_correct) / nullif(count(*),0), 2) as accuracy_pct,
    avg(avg_time)::int as avg_time_ms,
    max(last_attempt) as last_attempt_at
  from unique_questions;
$$;

-- Updated topic cards function to count unique questions
create or replace function public.get_user_topic_cards(
  p_user_id uuid,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  topic_id uuid,
  topic_name text,
  specialty_id uuid,
  total_questions integer,
  attempted_questions integer,
  accuracy_pct numeric,
  avg_time_ms integer,
  last_studied timestamptz
) language sql stable security definer as $$
  with per_topic_attempts as (
    select
      q.topic_id,
      count(distinct a.question_id)::int as attempted_questions,
      count(*) filter (where a.is_correct)::int as correct_attempts,
      count(distinct case when a.is_correct then a.question_id end)::int as correct_questions,
      avg(a.time_taken_ms)::int as avg_time_ms,
      max(a.attempted_at) as last_studied
    from user_question_attempts a
    join questions q on q.id = a.question_id
    where a.user_id = p_user_id
    group by q.topic_id
  )
  select
    t.id as topic_id,
    t.name as topic_name,
    t.specialty_id,
    coalesce(vc.total_questions, 0)::int as total_questions,
    coalesce(pta.attempted_questions, 0)::int as attempted_questions,
    round(100.0 * coalesce(pta.correct_questions,0) / nullif(coalesce(pta.attempted_questions,0),0), 2) as accuracy_pct,
    pta.avg_time_ms,
    pta.last_studied
  from topics t
  left join v_topic_question_counts vc on vc.topic_id = t.id
  left join per_topic_attempts pta on pta.topic_id = t.id
  order by t.name
  limit p_limit offset p_offset;
$$;

drop function if exists public.get_user_specialty_cards(uuid);
create function public.get_user_specialty_cards(p_user_id uuid)
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
  with specialty_stats as (
    select
      s.id as specialty_id,
      s.name as specialty_name,
      s.slug as specialty_slug,
      count(distinct q.id)::int as total_questions,
      count(distinct a.question_id)::int as completed_questions,
      count(distinct case when a.is_correct then a.question_id end)::int as correct_questions,
      avg(a.time_taken_ms)::int as avg_time_ms,
      max(a.attempted_at) as last_studied,
      array_agg(distinct t.slug order by t.slug) filter (where t.slug is not null) as key_topics
    from specialties s
    left join topics t on t.specialty_id = s.id
    left join questions q on q.topic_id = t.id and q.is_active = true
    left join user_question_attempts a on a.question_id = q.id and a.user_id = p_user_id
    group by s.id, s.name, s.slug
  )
  select
    ss.specialty_id,
    ss.specialty_name,
    ss.specialty_slug,
    s.icon_name,
    s.icon_color,
    s.icon_bg_start,
    s.icon_bg_end,
    ss.total_questions,
    ss.completed_questions,
    round(100.0 * ss.correct_questions / nullif(ss.completed_questions, 0), 2) as accuracy_pct,
    ss.avg_time_ms,
    ss.last_studied,
    ss.key_topics
  from specialty_stats ss
  left join specialties s on s.id = ss.specialty_id
  where ss.total_questions > 0
  order by ss.specialty_name;
$$;
