create table if not exists public.govi_live_gifts (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.govi_live_sessions(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 gift_name text not null check (char_length(gift_name) between 1 and 40),
 created_at timestamptz not null default now()
);
alter table public.govi_live_gifts enable row level security;
drop policy if exists "govi_live_gifts_read" on public.govi_live_gifts;
create policy "govi_live_gifts_read" on public.govi_live_gifts for select to authenticated using (true);
drop policy if exists "govi_live_gifts_send" on public.govi_live_gifts;
create policy "govi_live_gifts_send" on public.govi_live_gifts for insert to authenticated with check (sender_id = auth.uid());
grant select, insert on public.govi_live_gifts to authenticated;
do $$ begin alter publication supabase_realtime add table public.govi_live_gifts; exception when duplicate_object then null; end $$;
