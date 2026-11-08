-- GOVI PRIVATE MESSAGES
-- Run this script once in Supabase SQL Editor for project NEXORA.
-- Only the sender and recipient can read each message. Attachments use a private bucket.

create extension if not exists pgcrypto;

create table if not exists public.govi_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '',
  media_path text,
  media_type text,
  created_at timestamptz not null default now(),
  constraint govi_messages_no_self_message check (sender_id <> recipient_id),
  constraint govi_messages_content_length check (char_length(content) <= 5000),
  constraint govi_messages_not_empty check (
    length(trim(content)) > 0 or media_path is not null
  )
);

create index if not exists govi_messages_sender_created_idx
  on public.govi_messages (sender_id, created_at desc);
create index if not exists govi_messages_recipient_created_idx
  on public.govi_messages (recipient_id, created_at desc);

alter table public.govi_messages enable row level security;

drop policy if exists "Participants can read private messages" on public.govi_messages;
create policy "Participants can read private messages"
  on public.govi_messages for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists "Users can send messages as themselves" on public.govi_messages;
create policy "Users can send messages as themselves"
  on public.govi_messages for insert to authenticated
  with check (
    auth.uid() = sender_id
    and sender_id <> recipient_id
    and exists (select 1 from auth.users u where u.id = recipient_id)
  );

-- Private bucket for message photos. No public URLs are used.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'govi-private-messages',
  'govi-private-messages',
  false,
  15728640,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = false,
    file_size_limit = 15728640,
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "Users upload message photos to own folder" on storage.objects;
create policy "Users upload message photos to own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'govi-private-messages'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Participants can view private message photos" on storage.objects;
create policy "Participants can view private message photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'govi-private-messages'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.govi_messages m
        where m.media_path = storage.objects.name
          and (m.sender_id = auth.uid() or m.recipient_id = auth.uid())
      )
    )
  );
