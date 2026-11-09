-- GOVI CONTROL CENTER: esquema inicial de administración, métricas y reclamaciones.
-- Ejecutar en Supabase SQL Editor después de revisar el despliegue.
-- No concede acceso de fundador automáticamente: registrar el UUID del fundador
-- en govi_admins desde un entorno de confianza antes de habilitar el panel.

create table if not exists public.govi_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'founder' check (role in ('founder','moderator','analyst')),
  created_at timestamptz not null default now()
);

create or replace function public.govi_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.govi_admins a
    where a.user_id = (select auth.uid())
  );
$$;

revoke all on function public.govi_is_admin() from public;
grant execute on function public.govi_is_admin() to authenticated;

create table if not exists public.govi_live_sessions (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references auth.users(id) on delete cascade,
  provider_room_id text unique,
  title text not null,
  category text,
  stream_type text not null check (stream_type in ('irl','obs')),
  status text not null default 'live' check (status in ('live','ended','interrupted','moderated')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  peak_viewers integer not null default 0 check (peak_viewers >= 0),
  total_viewer_minutes bigint not null default 0 check (total_viewer_minutes >= 0),
  unique_viewers bigint not null default 0 check (unique_viewers >= 0),
  created_at timestamptz not null default now()
);
create index if not exists govi_live_sessions_status_started
  on public.govi_live_sessions(status, started_at desc);
create index if not exists govi_live_sessions_streamer_started
  on public.govi_live_sessions(streamer_id, started_at desc);

create table if not exists public.govi_live_metrics (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.govi_live_sessions(id) on delete cascade,
  captured_at timestamptz not null default now(),
  concurrent_viewers integer not null default 0 check (concurrent_viewers >= 0),
  bandwidth_bytes bigint not null default 0 check (bandwidth_bytes >= 0)
);
create index if not exists govi_live_metrics_session_time
  on public.govi_live_metrics(session_id, captured_at desc);

create table if not exists public.govi_copyright_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  reporter_name text not null,
  reporter_email text not null,
  rights_holder text not null,
  work_title text not null,
  work_type text not null check (work_type in ('music','video','broadcast','image','other')),
  infringing_url text not null,
  timestamp_or_location text,
  explanation text not null,
  good_faith_statement boolean not null default false check (good_faith_statement),
  authority_statement boolean not null default false check (authority_statement),
  status text not null default 'received' check (status in ('received','reviewing','action_taken','rejected','appealed','closed')),
  admin_notes text,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists govi_copyright_reports_status_created
  on public.govi_copyright_reports(status, created_at desc);

create table if not exists public.govi_copyright_evidence (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.govi_copyright_reports(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  created_at timestamptz not null default now()
);
create index if not exists govi_copyright_evidence_report
  on public.govi_copyright_evidence(report_id);

alter table public.govi_admins enable row level security;
alter table public.govi_live_sessions enable row level security;
alter table public.govi_live_metrics enable row level security;
alter table public.govi_copyright_reports enable row level security;
alter table public.govi_copyright_evidence enable row level security;

-- Nadie puede enumerar la lista de administradores desde el cliente.
drop policy if exists "GOVI founder reads admin roster" on public.govi_admins;
create policy "GOVI founder reads admin roster" on public.govi_admins
for select to authenticated using (public.govi_is_admin());

-- Los creadores solo pueden leer/crear/actualizar sus propias sesiones.
drop policy if exists "GOVI streamers read own sessions" on public.govi_live_sessions;
create policy "GOVI streamers read own sessions" on public.govi_live_sessions
for select to authenticated using (streamer_id = (select auth.uid()) or public.govi_is_admin());
drop policy if exists "GOVI streamers create own sessions" on public.govi_live_sessions;
create policy "GOVI streamers create own sessions" on public.govi_live_sessions
for insert to authenticated with check (streamer_id = (select auth.uid()));
drop policy if exists "GOVI streamers update own sessions" on public.govi_live_sessions;
create policy "GOVI streamers update own sessions" on public.govi_live_sessions
for update to authenticated using (streamer_id = (select auth.uid()) or public.govi_is_admin())
with check (streamer_id = (select auth.uid()) or public.govi_is_admin());

-- Métricas visibles únicamente para el creador de la sesión y administradores.
drop policy if exists "GOVI owners and admins read live metrics" on public.govi_live_metrics;
create policy "GOVI owners and admins read live metrics" on public.govi_live_metrics
for select to authenticated using (
  public.govi_is_admin() or exists (
    select 1 from public.govi_live_sessions s
    where s.id = session_id and s.streamer_id = (select auth.uid())
  )
);

-- El público puede presentar una reclamación; solo administradores la consultan y resuelven.
drop policy if exists "GOVI anyone submits copyright report" on public.govi_copyright_reports;
create policy "GOVI anyone submits copyright report" on public.govi_copyright_reports
for insert to anon, authenticated with check (good_faith_statement and authority_statement);
drop policy if exists "GOVI admins read copyright reports" on public.govi_copyright_reports;
create policy "GOVI admins read copyright reports" on public.govi_copyright_reports
for select to authenticated using (public.govi_is_admin());
drop policy if exists "GOVI admins update copyright reports" on public.govi_copyright_reports;
create policy "GOVI admins update copyright reports" on public.govi_copyright_reports
for update to authenticated using (public.govi_is_admin()) with check (public.govi_is_admin());

drop policy if exists "GOVI admins manage copyright evidence" on public.govi_copyright_evidence;
create policy "GOVI admins manage copyright evidence" on public.govi_copyright_evidence
for all to authenticated using (public.govi_is_admin()) with check (public.govi_is_admin());

revoke all on public.govi_admins from anon, authenticated;
grant select on public.govi_admins to authenticated;
revoke all on public.govi_live_sessions from anon;
grant select, insert, update on public.govi_live_sessions to authenticated;
revoke all on public.govi_live_metrics from anon, authenticated;
grant select on public.govi_live_metrics to authenticated;
revoke all on public.govi_copyright_reports from anon, authenticated;
grant insert on public.govi_copyright_reports to anon, authenticated;
grant select, update on public.govi_copyright_reports to authenticated;
revoke all on public.govi_copyright_evidence from anon, authenticated;
grant select, insert, update, delete on public.govi_copyright_evidence to authenticated;

-- IMPORTANTE:
-- 1) El alta inicial del fundador se hace con el UUID real de auth.users desde Supabase SQL Editor.
-- 2) No colocar service_role ni secretos de LiveKit en index.html.
-- 3) La creación de tokens LiveKit y los cambios de permisos deben pasar por Edge Functions/servidor.
-- 4) Las métricas deben ser escritas por webhooks/servidor verificado, no por el navegador del streamer.
