-- GOVI OFFICIAL PAGES v1
-- Additive migration: keeps existing user posts, likes, comments and friendships intact.
-- Run in Supabase > SQL Editor after deploying the matching frontend.

create table if not exists public.govi_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category text not null default 'General',
  description text not null default '',
  avatar_url text,
  cover_url text,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.govi_page_follows (
  page_id uuid not null references public.govi_pages(id) on delete cascade,
  follower_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (page_id, follower_id)
);
create index if not exists govi_page_follows_follower on public.govi_page_follows(follower_id, created_at desc);
create index if not exists govi_page_follows_page on public.govi_page_follows(page_id);

alter table public.posts add column if not exists page_id uuid references public.govi_pages(id) on delete set null;
create index if not exists govi_posts_page_created on public.posts(page_id, created_at desc) where page_id is not null;

alter table public.govi_pages enable row level security;
alter table public.govi_page_follows enable row level security;

drop policy if exists "GOVI active pages are visible" on public.govi_pages;
create policy "GOVI active pages are visible" on public.govi_pages
for select to anon, authenticated using (is_active = true or public.govi_is_admin());

drop policy if exists "GOVI admins create pages" on public.govi_pages;
create policy "GOVI admins create pages" on public.govi_pages
for insert to authenticated with check (public.govi_is_admin());

drop policy if exists "GOVI admins update pages" on public.govi_pages;
create policy "GOVI admins update pages" on public.govi_pages
for update to authenticated using (public.govi_is_admin()) with check (public.govi_is_admin());

drop policy if exists "GOVI admins delete pages" on public.govi_pages;
create policy "GOVI admins delete pages" on public.govi_pages
for delete to authenticated using (public.govi_is_admin());

drop policy if exists "GOVI page follows are visible" on public.govi_page_follows;
create policy "GOVI page follows are visible" on public.govi_page_follows
for select to authenticated using (true);

drop policy if exists "GOVI users follow pages as themselves" on public.govi_page_follows;
create policy "GOVI users follow pages as themselves" on public.govi_page_follows
for insert to authenticated with check (follower_id = auth.uid());

drop policy if exists "GOVI users unfollow pages as themselves" on public.govi_page_follows;
create policy "GOVI users unfollow pages as themselves" on public.govi_page_follows
for delete to authenticated using (follower_id = auth.uid());

create or replace function public.govi_follow_page(target_page_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inicia sesión para seguir una página'; end if;
  if not exists (select 1 from public.govi_pages where id=target_page_id and is_active=true) then
    raise exception 'La página no está disponible';
  end if;
  insert into public.govi_page_follows(page_id,follower_id)
  values(target_page_id,me) on conflict do nothing;
  return 'following';
end; $$;

create or replace function public.govi_unfollow_page(target_page_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inicia sesión'; end if;
  delete from public.govi_page_follows where page_id=target_page_id and follower_id=me;
  return 'unfollowed';
end; $$;

revoke all on function public.govi_follow_page(uuid) from public;
revoke all on function public.govi_unfollow_page(uuid) from public;
grant execute on function public.govi_follow_page(uuid) to authenticated;
grant execute on function public.govi_unfollow_page(uuid) to authenticated;

grant select on public.govi_pages to anon, authenticated;
grant insert, update, delete on public.govi_pages to authenticated;
grant select, insert, delete on public.govi_page_follows to authenticated;

-- Seed only the existing built-in discovery entries as official page records.
-- They remain discoverable but are not automatically followed by any user.
insert into public.govi_pages(slug,name,category,description,is_verified,is_active)
values
 ('bloopers','Canal de Bloopers','Entretenimiento','Humor y momentos divertidos',false,true),
 ('discovery','Discovery Channel','Documentales','Ciencia, exploración y descubrimientos',false,true),
 ('discovery-kids','Discovery Kids','Infantil','Contenido educativo y familiar',false,true),
 ('animal-planet','Animal Planet','Naturaleza','Animales y vida salvaje',false,true),
 ('discovery-turbo','Discovery Turbo','Motor','Automóviles, motores y tecnología',false,true),
 ('cnn','CNN','Noticias','Actualidad y noticias internacionales',false,true),
 ('bbc-mundo','BBC Mundo','Noticias','Información internacional en español',false,true),
 ('national-geographic','National Geographic','Ciencia y naturaleza','Ciencia, fotografía y exploración',false,true),
 ('espn','ESPN','Deportes','Deportes y actualidad deportiva',false,true),
 ('cartoon-network','Cartoon Network','Animación','Series y entretenimiento animado',false,true)
on conflict (slug) do update set
 name=excluded.name,category=excluded.category,description=excluded.description,is_active=true,updated_at=now();
