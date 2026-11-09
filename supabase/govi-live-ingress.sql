-- Añade el identificador de Ingress de LiveKit a las sesiones GOVI LIVE.
-- No guarda la stream key: esa credencial solo se entrega al anfitrión al crearla.
alter table public.govi_live_sessions
  add column if not exists ingress_id text;
