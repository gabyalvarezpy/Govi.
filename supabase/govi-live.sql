-- GOVI LIVE — base de datos aislada para transmisiones en directo.
-- Ejecutar una sola vez en Supabase > SQL Editor. No modifica tablas existentes.

create table if not exists public.govi_live_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  room_name text not null unique,
  title text not null check (char_length(title) between 1 and 100),
  description text not null default '' check (char_length(description) <= 500),
  status text not null default 'live' check (status in ('live','ended')),
  chat_enabled boolean not null default true,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  constraint govi_live_end_time_check check (
    (status = 'live' and ended_at is null) or
    (status = 'ended' and ended_at is not null)
  )
);

create index if not exists govi_live_sessions_status_started
  on public.govi_live_sessions(status, started_at desc);
create index if not exists govi_live_sessions_host_started
  on public.govi_live_sessions(host_id, started_at desc);

create table if not exists public.govi_live_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.govi_live_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists govi_live_messages_session_created
  on public.govi_live_messages(session_id, created_at asc);

alter table public.govi_live_sessions enable row level security;
alter table public.govi_live_messages enable row level security;

drop policy if exists "GOVI LIVE authenticated users view sessions" on public.govi_live_sessions;
create policy "GOVI LIVE authenticated users view sessions"
  on public.govi_live_sessions for select to authenticated
  using (true);

drop policy if exists "GOVI LIVE users start own sessions" on public.govi_live_sessions;
create policy "GOVI LIVE users start own sessions"
  on public.govi_live_sessions for insert to authenticated
  with check (host_id = auth.uid() and status = 'live' and ended_at is null);

drop policy if exists "GOVI LIVE hosts update own sessions" on public.govi_live_sessions;
create policy "GOVI LIVE hosts update own sessions"
  on public.govi_live_sessions for update to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

drop policy if exists "GOVI LIVE authenticated users read chat" on public.govi_live_messages;
create policy "GOVI LIVE authenticated users read chat"
  on public.govi_live_messages for select to authenticated
  using (
    exists (
      select 1 from public.govi_live_sessions s
      where s.id = session_id
        and s.status = 'live'
    )
  );

drop policy if exists "GOVI LIVE users send chat to live sessions" on public.govi_live_messages;
create policy "GOVI LIVE users send chat to live sessions"
  on public.govi_live_messages for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.govi_live_sessions s
      where s.id = session_id
        and s.status = 'live'
        and s.chat_enabled = true
    )
  );

drop policy if exists "GOVI LIVE users delete own chat" on public.govi_live_messages;
create policy "GOVI LIVE users delete own chat"
  on public.govi_live_messages for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.govi_live_sessions s
      where s.id = session_id and s.host_id = auth.uid()
    )
  );

grant select, insert, update on public.govi_live_sessions to authenticated;
grant select, insert, delete on public.govi_live_messages to authenticated;

-- Realtime para que las salas y el chat se actualicen sin recargar la página.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'govi_live_sessions'
    ) then
      alter publication supabase_realtime add table public.govi_live_sessions;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'govi_live_messages'
    ) then
      alter publication supabase_realtime add table public.govi_live_messages;
    end if;
  end if;
end $$;
