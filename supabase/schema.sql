-- Held: Supabase schema. Paste into the Supabase SQL editor and run. Safe to run again to upgrade.
-- Design: the tables are locked. The browser only talks to the functions below.
-- A circle is reached by an unguessable id (the family link). The mother owns it with either:
--   1. an owner key kept in her browser, or
--   2. her Auth0 login (the "sub" claim in her signed token), so she can open it on any phone.
-- Mood scores and notes are never stored here. Only "needs support" (true or false).

create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  owner_key uuid not null default gen_random_uuid(),
  owner_sub text,
  mom_name text not null check (char_length(mom_name) between 1 and 60),
  needs_support boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.circles add column if not exists owner_sub text;
create index if not exists circles_owner_sub_idx on public.circles (owner_sub);

create table if not exists public.requests (
  id uuid primary key,
  circle_id uuid not null references public.circles(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 200),
  kind text not null default 'custom',
  gift text not null default '',
  when_key text not null check (when_key in ('today', 'tomorrow', 'week')),
  due_at timestamptz not null,
  claimed_by text,
  done boolean not null default false,
  done_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.circles enable row level security;
alter table public.requests enable row level security;
revoke all on public.circles from anon, authenticated;
revoke all on public.requests from anon, authenticated;

-- Internal helper: is the caller the owner (by key, or by signed in Auth0 user)?
-- Note: Auth0 ids look like "auth0|abc123", which are not UUIDs, so we read the "sub" claim as text.
create or replace function public.is_owner(p_circle uuid, p_key uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.circles c
    where c.id = p_circle
      and ((p_key is not null and c.owner_key = p_key)
        or (c.owner_sub is not null and c.owner_sub = nullif(auth.jwt() ->> 'sub', '')))
  );
$$;
revoke execute on function public.is_owner(uuid, uuid) from public, anon, authenticated;

create or replace function public.create_circle(p_mom text) returns json
language plpgsql security definer set search_path = public as $$
declare c public.circles;
begin
  if p_mom is null or char_length(trim(p_mom)) = 0 then raise exception 'name required'; end if;
  insert into public.circles (mom_name, owner_sub)
  values (left(trim(p_mom), 60), nullif(auth.jwt() ->> 'sub', ''))
  returning * into c;
  return json_build_object('id', c.id, 'owner_key', c.owner_key);
end $$;

-- The circle that belongs to the signed in user (used when logging in on a new phone).
create or replace function public.my_circle() returns json
language sql security definer stable set search_path = public as $$
  select json_build_object('id', c.id, 'mom', c.mom_name)
  from public.circles c
  where c.owner_sub is not null and c.owner_sub = nullif(auth.jwt() ->> 'sub', '')
  order by c.created_at desc limit 1;
$$;

-- Attach a circle created before login to the signed in user. Needs the owner key.
create or replace function public.claim_circle_for_user(p_circle uuid, p_key uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s text := nullif(auth.jwt() ->> 'sub', '');
begin
  if s is null then raise exception 'sign in required'; end if;
  update public.circles set owner_sub = s
  where id = p_circle and owner_key = p_key and (owner_sub is null or owner_sub = s);
  if not found then raise exception 'not allowed'; end if;
end $$;

create or replace function public.get_circle(p_id uuid) returns json
language sql security definer stable set search_path = public as $$
  select json_build_object(
    'mom', c.mom_name,
    'needs', c.needs_support,
    'requests', coalesce((
      select json_agg(json_build_object(
        'id', r.id, 'text', r.label, 'kind', r.kind, 'gift', r.gift, 'when', r.when_key,
        'due', (extract(epoch from r.due_at) * 1000)::bigint,
        'claimedBy', coalesce(r.claimed_by, ''), 'done', r.done
      ) order by r.created_at desc)
      from public.requests r where r.circle_id = c.id
    ), '[]'::json))
  from public.circles c where c.id = p_id;
$$;

create or replace function public.owner_set_status(p_circle uuid, p_key uuid, p_mom text, p_needs boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_circle, p_key) then raise exception 'not allowed'; end if;
  update public.circles set needs_support = p_needs, mom_name = left(trim(p_mom), 60) where id = p_circle;
end $$;

create or replace function public.owner_add_request(
  p_circle uuid, p_key uuid, p_id uuid, p_text text, p_kind text, p_gift text, p_when text, p_due bigint
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_circle, p_key) then raise exception 'not allowed'; end if;
  if (select count(*) from public.requests where circle_id = p_circle) >= 100 then raise exception 'too many requests'; end if;
  if p_gift not in ('', 'https://www.doordash.com/', 'https://www.instacart.com/') then raise exception 'link not allowed'; end if;
  insert into public.requests (id, circle_id, label, kind, gift, when_key, due_at)
  values (p_id, p_circle, left(trim(p_text), 200), left(coalesce(p_kind, 'custom'), 20), p_gift, p_when, to_timestamp(p_due / 1000.0))
  on conflict (id) do nothing;
end $$;

create or replace function public.owner_remove_request(p_circle uuid, p_key uuid, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_circle, p_key) then raise exception 'not allowed'; end if;
  delete from public.requests where id = p_id and circle_id = p_circle;
end $$;

create or replace function public.owner_set_done(p_circle uuid, p_key uuid, p_id uuid, p_done boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_circle, p_key) then raise exception 'not allowed'; end if;
  update public.requests set done = p_done, done_at = case when p_done then now() else null end
  where id = p_id and circle_id = p_circle;
end $$;

-- Family actions: only the circle id is needed (the unguessable link).
create or replace function public.claim_request(p_circle uuid, p_id uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_name is null or char_length(trim(p_name)) = 0 then raise exception 'name required'; end if;
  update public.requests set claimed_by = left(trim(p_name), 40)
  where id = p_id and circle_id = p_circle and claimed_by is null and not done;
end $$;

create or replace function public.unclaim_request(p_circle uuid, p_id uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.requests set claimed_by = null, done = false, done_at = null
  where id = p_id and circle_id = p_circle and claimed_by = trim(p_name);
end $$;

create or replace function public.family_set_done(p_circle uuid, p_id uuid, p_name text, p_done boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.requests set done = p_done, done_at = case when p_done then now() else null end
  where id = p_id and circle_id = p_circle and claimed_by = trim(p_name);
end $$;

grant execute on function
  public.create_circle(text), public.my_circle(), public.claim_circle_for_user(uuid, uuid),
  public.get_circle(uuid), public.owner_set_status(uuid, uuid, text, boolean),
  public.owner_add_request(uuid, uuid, uuid, text, text, text, text, bigint),
  public.owner_remove_request(uuid, uuid, uuid), public.owner_set_done(uuid, uuid, uuid, boolean),
  public.claim_request(uuid, uuid, text), public.unclaim_request(uuid, uuid, text),
  public.family_set_done(uuid, uuid, text, boolean)
to anon, authenticated;
