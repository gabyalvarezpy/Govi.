-- GOVI LIVE recordings metadata. Run once in Supabase SQL Editor.
create table if not exists public.govi_live_recordings (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.govi_live_sessions(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  egress_id text not null unique,
  bucket text not null default 'govi-live-recordings',
  object_path text not null,
  status text not null default 'recording' check (status in ('recording','processing','ready','failed')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists govi_live_recordings_host_created
  on public.govi_live_recordings(host_id, created_at desc);
alter table public.govi_live_recordings enable row level security;
drop policy if exists "GOVI LIVE hosts view own recordings" on public.govi_live_recordings;
create policy "GOVI LIVE hosts view own recordings"
  on public.govi_live_recordings for select to authenticated
  using (host_id = auth.uid());
grant select on public.govi_live_recordings to authenticated;
