-- GOVI CONTROL CENTER · resumen privado del fundador
-- Ejecutar en Supabase SQL Editor. No modifica tablas ni funciones existentes.

CREATE OR REPLACE FUNCTION public.govi_admin_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.govi_is_admin() THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'users', (SELECT count(*) FROM public.profiles),
    'posts', (SELECT count(*) FROM public.posts),
    'stories', (SELECT count(*) FROM public.stories),
    'live_sessions', (SELECT count(*) FROM public.govi_live_sessions),
    'live_now', (SELECT count(*) FROM public.govi_live_sessions WHERE status = 'live'),
    'copyright_reports', (SELECT count(*) FROM public.govi_copyright_reports)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.govi_admin_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.govi_admin_overview() TO authenticated;
