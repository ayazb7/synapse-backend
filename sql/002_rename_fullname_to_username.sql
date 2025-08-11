-- Migration to switch from full_name to username

-- 1) If the column already exists as full_name, rename it to username
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'full_name'
  ) then
    alter table public.users rename column full_name to username;
  end if;
end $$;

-- 2) Ensure uniqueness on username if present
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'username'
  ) then
    -- add unique index if not already present
    create unique index if not exists users_username_key on public.users (username);
  end if;
end $$;

-- 3) Update trigger function to read username from raw_user_meta_data
create or replace function public.handle_new_auth_user()
returns trigger as $$
begin
  insert into public.users (id, email, username)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'username', ''))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;


