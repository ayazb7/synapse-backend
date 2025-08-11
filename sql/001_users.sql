-- Creates a public.users table and a trigger to sync from auth.users
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create or replace function public.handle_new_auth_user()
returns trigger as $$
begin
  insert into public.users (id, email, username)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'username', ''))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

-- Keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_public_users_updated_at on public.users;
create trigger set_public_users_updated_at
before update on public.users
for each row execute procedure public.set_updated_at();

-- Row Level Security and policies
alter table public.users enable row level security;

-- Read own row
create policy "Users can select their own profile"
on public.users for select
to authenticated
using (auth.uid() = id);

-- Update own row
create policy "Users can update their own profile"
on public.users for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);


