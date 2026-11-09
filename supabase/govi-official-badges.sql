-- GOVI OFFICIAL BADGES · Founder + verification requests
-- Run once in Supabase SQL Editor. Does not alter existing social tables.

CREATE TABLE IF NOT EXISTS public.govi_badge_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  friends_at_request integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS public.govi_verified_badges (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_type text NOT NULL CHECK (badge_type IN ('founder','official')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

ALTER TABLE public.govi_badge_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.govi_verified_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "GOVI users read own badge requests" ON public.govi_badge_requests;
CREATE POLICY "GOVI users read own badge requests" ON public.govi_badge_requests
FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "GOVI public read active badges" ON public.govi_verified_badges;
CREATE POLICY "GOVI public read active badges" ON public.govi_verified_badges
FOR SELECT TO anon, authenticated USING (status = 'active');

CREATE OR REPLACE FUNCTION public.govi_request_official_badge()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,auth AS $$
DECLARE me uuid := auth.uid(); friend_count integer;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Inicia sesión para solicitar la insignia'; END IF;
  IF me = '5e631491-4c29-4e8d-9aff-0e40bcd3b7f9'::uuid THEN
    RETURN 'founder_badge_reserved';
  END IF;
  SELECT count(*) INTO friend_count
  FROM public.govi_friendships
  WHERE status='accepted' AND (requester_id=me OR addressee_id=me);
  IF friend_count < 500 THEN RAISE EXCEPTION 'Necesitas 500 amistades aceptadas para solicitar la insignia'; END IF;
  IF EXISTS(SELECT 1 FROM public.govi_verified_badges WHERE user_id=me AND status='active') THEN
    RETURN 'already_verified';
  END IF;
  INSERT INTO public.govi_badge_requests(user_id,friends_at_request,status)
  VALUES(me,friend_count,'pending')
  ON CONFLICT(user_id) DO UPDATE SET friends_at_request=EXCLUDED.friends_at_request,status='pending',created_at=now(),reviewed_at=NULL
  WHERE public.govi_badge_requests.status <> 'approved';
  RETURN 'request_submitted';
END;
$$;

REVOKE ALL ON FUNCTION public.govi_request_official_badge() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.govi_request_official_badge() TO authenticated;

-- Founder badge: permanent and free.
INSERT INTO public.govi_verified_badges(user_id,badge_type,status,expires_at)
VALUES('5e631491-4c29-4e8d-9aff-0e40bcd3b7f9'::uuid,'founder','active',NULL)
ON CONFLICT(user_id) DO UPDATE SET badge_type='founder',status='active',expires_at=NULL;
