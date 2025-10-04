-- Likes for question comments and helper RPCs for listing comments with counts

create table if not exists public.question_comment_likes (
  user_id uuid not null references public.users(id) on delete cascade,
  comment_id uuid not null references public.question_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint question_comment_likes_pkey primary key (user_id, comment_id)
) tablespace pg_default;

create index if not exists question_comment_likes_comment_idx on public.question_comment_likes using btree (comment_id);

-- Return top-level comments for a question with like_count, liked, and reply_count
create or replace function public.get_question_comments(
  p_user_id uuid,
  p_question_id uuid
)
returns table (
  id uuid,
  question_id uuid,
  user_id uuid,
  user_username text,
  user_email text,
  parent_id uuid,
  content text,
  created_at timestamptz,
  updated_at timestamptz,
  like_count integer,
  liked boolean,
  reply_count integer
) language sql stable as $$
  select c.id,
         c.question_id,
         c.user_id,
         u.username as user_username,
         u.email as user_email,
         c.parent_id,
         c.content,
         c.created_at,
         c.updated_at,
         coalesce(lc.cnt, 0) as like_count,
         exists(select 1 from public.question_comment_likes l where l.comment_id = c.id and l.user_id = p_user_id) as liked,
         coalesce(rc.cnt, 0) as reply_count
  from public.question_comments c
  join public.users u on u.id = c.user_id
  left join (
    select comment_id, count(*) as cnt from public.question_comment_likes group by comment_id
  ) lc on lc.comment_id = c.id
  left join (
    select parent_id, count(*) as cnt from public.question_comments where parent_id is not null group by parent_id
  ) rc on rc.parent_id = c.id
  where c.question_id = p_question_id and c.parent_id is null
  order by coalesce(lc.cnt,0) desc, c.created_at asc;
$$;

-- Return replies for a parent comment with counts
create or replace function public.get_comment_replies(
  p_user_id uuid,
  p_parent_id uuid
)
returns table (
  id uuid,
  question_id uuid,
  user_id uuid,
  user_username text,
  user_email text,
  parent_id uuid,
  content text,
  created_at timestamptz,
  updated_at timestamptz,
  like_count integer,
  liked boolean
) language sql stable as $$
  select c.id,
         c.question_id,
         c.user_id,
         u.username as user_username,
         u.email as user_email,
         c.parent_id,
         c.content,
         c.created_at,
         c.updated_at,
         coalesce(lc.cnt, 0) as like_count,
         exists(select 1 from public.question_comment_likes l where l.comment_id = c.id and l.user_id = p_user_id) as liked
  from public.question_comments c
  join public.users u on u.id = c.user_id
  left join (
    select comment_id, count(*) as cnt from public.question_comment_likes group by comment_id
  ) lc on lc.comment_id = c.id
  where c.parent_id = p_parent_id
  order by coalesce(lc.cnt,0) desc, c.created_at asc;
$$;


