-- Aggregate totals for a user across all questions
create or replace function public.get_user_totals(p_user_id uuid)
returns table (
  total_answered integer,
  correct integer,
  accuracy_pct numeric,
  avg_time_ms integer,
  last_attempt_at timestamptz
) language sql stable security definer as $$
  select
    count(*)::int as total_answered,
    count(*) filter (where is_correct)::int as correct,
    round(100.0 * count(*) filter (where is_correct) / nullif(count(*),0), 2) as accuracy_pct,
    avg(time_taken_ms)::int as avg_time_ms,
    max(attempted_at) as last_attempt_at
  from user_question_attempts
  where user_id = p_user_id;
$$;

-- Topic cards with progress and performance per topic for a user
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
      count(*) filter (where a.is_correct)::int as correct,
      count(*)::int as attempts,
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
    round(100.0 * coalesce(pta.correct,0) / nullif(coalesce(pta.attempts,0),0), 2) as accuracy_pct,
    pta.avg_time_ms,
    pta.last_studied
  from topics t
  left join v_topic_question_counts vc on vc.topic_id = t.id
  left join per_topic_attempts pta on pta.topic_id = t.id
  order by t.name
  limit p_limit offset p_offset;
$$;


