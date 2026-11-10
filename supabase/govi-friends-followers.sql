-- GOVI: amistades (maximo 1000 aceptadas por perfil) y seguidores.
-- Ejecutar una sola vez en Supabase > SQL Editor > New query.

create table if not exists public.govi_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint govi_friendships_no_self check (requester_id <> addressee_id)
);

create unique index if not exists govi_friendships_pending_pair
on public.govi_friendships (requester_id, addressee_id) where status='pending';
create unique index if not exists govi_friendships_accepted_pair
on public.govi_friendships (least(requester_id,addressee_id), greatest(requester_id,addressee_id)) where status='accepted';
create index if not exists govi_friendships_addressee_status
on public.govi_friendships (addressee_id,status);
create index if not exists govi_friendships_requester_status
on public.govi_friendships (requester_id,status);

create table if not exists public.govi_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id,followed_id),
  constraint govi_follows_no_self check (follower_id <> followed_id)
);
create index if not exists govi_follows_followed on public.govi_follows(followed_id);

alter table public.govi_friendships enable row level security;
alter table public.govi_follows enable row level security;

drop policy if exists "GOVI friendship participants can read" on public.govi_friendships;
create policy "GOVI friendship participants can read" on public.govi_friendships
for select to authenticated using (auth.uid()=requester_id or auth.uid()=addressee_id);

drop policy if exists "GOVI users can read follow relations" on public.govi_follows;
create policy "GOVI users can read follow relations" on public.govi_follows
for select to authenticated using (true);

create or replace function public.govi_send_friend_request(target_user_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); mine_count integer; theirs_count integer;
begin
  if me is null then raise exception 'Inicia sesión para agregar amistades'; end if;
  if target_user_id is null or target_user_id=me then raise exception 'No puedes agregarte a ti mismo'; end if;
  if me::text < target_user_id::text then perform pg_advisory_xact_lock(hashtextextended(me::text,0)); perform pg_advisory_xact_lock(hashtextextended(target_user_id::text,0)); else perform pg_advisory_xact_lock(hashtextextended(target_user_id::text,0)); perform pg_advisory_xact_lock(hashtextextended(me::text,0)); end if;
  if not exists(select 1 from public.profiles where id=target_user_id) then raise exception 'No se encontró ese perfil'; end if;
  select count(*) into mine_count from public.govi_friendships where status='accepted' and (requester_id=me or addressee_id=me);
  select count(*) into theirs_count from public.govi_friendships where status='accepted' and (requester_id=target_user_id or addressee_id=target_user_id);
  if theirs_count>=1000 then return 'follow_required'; end if;
  if exists(select 1 from public.govi_friendships where status='accepted' and ((requester_id=me and addressee_id=target_user_id) or (requester_id=target_user_id and addressee_id=me))) then return 'already_friends'; end if;
  if exists(select 1 from public.govi_friendships where status='pending' and requester_id=target_user_id and addressee_id=me) then return 'incoming_request'; end if;
  insert into public.govi_friendships(requester_id,addressee_id,status)
  values(me,target_user_id,'pending')
  on conflict (requester_id,addressee_id) where status='pending' do nothing;
  return 'request_sent';
end; $$;

create or replace function public.govi_respond_friend_request(request_id uuid, accept_request boolean)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); req public.govi_friendships%rowtype; mine_count integer; theirs_count integer;
begin
  if me is null then raise exception 'Inicia sesión'; end if;
  select * into req from public.govi_friendships where id=request_id and addressee_id=me and status='pending' for update;
  if not found then raise exception 'La solicitud ya no está disponible'; end if;
  if me::text < req.requester_id::text then perform pg_advisory_xact_lock(hashtextextended(me::text,0)); perform pg_advisory_xact_lock(hashtextextended(req.requester_id::text,0)); else perform pg_advisory_xact_lock(hashtextextended(req.requester_id::text,0)); perform pg_advisory_xact_lock(hashtextextended(me::text,0)); end if;
  if not accept_request then
    update public.govi_friendships set status='rejected',updated_at=now() where id=request_id;
    return 'rejected';
  end if;
  select count(*) into mine_count from public.govi_friendships where status='accepted' and (requester_id=me or addressee_id=me);
  select count(*) into theirs_count from public.govi_friendships where status='accepted' and (requester_id=req.requester_id or addressee_id=req.requester_id);
  if mine_count>=1000 or theirs_count>=1000 then return 'follow_required'; end if;
  update public.govi_friendships set status='accepted',updated_at=now() where id=request_id;
  return 'accepted';
end; $$;

create or replace function public.govi_follow_user(target_user_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid();
begin
  if me is null then raise exception 'Inicia sesión'; end if;
  if target_user_id is null or target_user_id=me then raise exception 'No puedes seguirte a ti mismo'; end if;
  if not exists(select 1 from public.profiles where id=target_user_id) then raise exception 'No se encontró ese perfil'; end if;
  insert into public.govi_follows(follower_id,followed_id) values(me,target_user_id) on conflict do nothing;
  return 'following';
end; $$;

create or replace function public.govi_unfollow_user(target_user_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid();
begin
  if me is null then raise exception 'Inicia sesión'; end if;
  delete from public.govi_follows where follower_id=me and followed_id=target_user_id;
  return 'unfollowed';
end; $$;

revoke all on function public.govi_send_friend_request(uuid) from public;
revoke all on function public.govi_respond_friend_request(uuid,boolean) from public;
revoke all on function public.govi_follow_user(uuid) from public;
revoke all on function public.govi_unfollow_user(uuid) from public;
grant execute on function public.govi_send_friend_request(uuid) to authenticated;
grant execute on function public.govi_respond_friend_request(uuid,boolean) to authenticated;
grant execute on function public.govi_follow_user(uuid) to authenticated;
grant execute on function public.govi_unfollow_user(uuid) to authenticated;
