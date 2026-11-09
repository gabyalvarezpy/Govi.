-- GOVI CONTROL CENTER · estadísticas de crecimiento de los últimos 30 días
-- Ejecutar en Supabase SQL Editor. No modifica tablas existentes.

CREATE OR REPLACE FUNCTION public.govi_admin_growth_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.govi_is_admin() THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'totals', jsonb_build_object(
      'users', (SELECT count(*) FROM auth.users),
      'posts', (SELECT count(*) FROM public.posts),
      'stories', (SELECT count(*) FROM public.stories)
    ),
    'daily', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'day', d.day::text,
        'users', (SELECT count(*) FROM auth.users u WHERE u.created_at >= d.day AND u.created_at < d.day + interval '1 day'),
        'posts', (SELECT count(*) FROM public.posts p WHERE p.created_at >= d.day AND p.created_at < d.day + interval '1 day'),
        'stories', (SELECT count(*) FROM public.stories s WHERE s.created_at >= d.day AND s.created_at < d.day + interval '1 day')
      ) ORDER BY d.day)
      FROM generate_series(current_date - 29, current_date, interval '1 day') AS d(day)
    ), '[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.govi_admin_growth_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.govi_admin_growth_stats() TO authenticated;
