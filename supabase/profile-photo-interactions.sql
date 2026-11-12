-- GOVI: reacciones y comentarios independientes por cada foto de la galería de perfil.
create table if not exists public.profile_photo_reactions (
  id uuid primary key default gen_random_uuid(),
  photo_key text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null default '❤️' check (reaction in ('👍','❤️','😂','😮','😢','🔥')),
  created_at timestamptz not null default now(),
  unique (photo_key, user_id)
);
create index if not exists profile_photo_reactions_photo_key_idx on public.profile_photo_reactions(photo_key);

create table if not exists public.profile_photo_comments (
  id uuid primary key default gen_random_uuid(),
  photo_key text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists profile_photo_comments_photo_key_idx on public.profile_photo_comments(photo_key, created_at);

alter table public.profile_photo_reactions enable row level security;
alter table public.profile_photo_comments enable row level security;

drop policy if exists "Public can read photo reactions" on public.profile_photo_reactions;
create policy "Public can read photo reactions" on public.profile_photo_reactions for select using (true);
drop policy if exists "Authenticated users react to profile photos" on public.profile_photo_reactions;
create policy "Authenticated users react to profile photos" on public.profile_photo_reactions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can change own photo reaction" on public.profile_photo_reactions;
create policy "Users can change own photo reaction" on public.profile_photo_reactions for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users can remove own photo reaction" on public.profile_photo_reactions;
create policy "Users can remove own photo reaction" on public.profile_photo_reactions for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Public can read profile photo comments" on public.profile_photo_comments;
create policy "Public can read profile photo comments" on public.profile_photo_comments for select using (true);
drop policy if exists "Authenticated users comment on profile photos" on public.profile_photo_comments;
create policy "Authenticated users comment on profile photos" on public.profile_photo_comments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can edit own photo comments" on public.profile_photo_comments;
create policy "Users can edit own photo comments" on public.profile_photo_comments for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users can delete own photo comments" on public.profile_photo_comments;
create policy "Users can delete own photo comments" on public.profile_photo_comments for delete to authenticated using (auth.uid() = user_id);

grant select on public.profile_photo_reactions, public.profile_photo_comments to anon, authenticated;
grant insert, update, delete on public.profile_photo_reactions, public.profile_photo_comments to authenticated;
