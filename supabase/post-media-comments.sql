-- GOVI: separar comentarios por foto dentro de cada álbum.
ALTER TABLE public.post_comments
ADD COLUMN IF NOT EXISTS media_index integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS post_comments_post_media_created_idx
ON public.post_comments (post_id, media_index, created_at);

-- Me gusta independientes para cada foto o vídeo de un álbum.
create table if not exists public.post_media_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  media_index integer not null default 0 check (media_index >= 0),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, media_index, user_id)
);
create index if not exists post_media_likes_post_media_idx
  on public.post_media_likes(post_id, media_index);
alter table public.post_media_likes enable row level security;
drop policy if exists "Public can read per-photo likes" on public.post_media_likes;
create policy "Public can read per-photo likes" on public.post_media_likes for select using (true);
drop policy if exists "Users can add own per-photo like" on public.post_media_likes;
create policy "Users can add own per-photo like" on public.post_media_likes for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can remove own per-photo like" on public.post_media_likes;
create policy "Users can remove own per-photo like" on public.post_media_likes for delete to authenticated using (auth.uid() = user_id);
grant select on public.post_media_likes to anon, authenticated;
grant insert, delete on public.post_media_likes to authenticated;
