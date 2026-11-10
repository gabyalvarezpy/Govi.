-- GOVI: campo de género para personalizar el aro/avatar de perfil.
-- Ejecutar una sola vez en Supabase > SQL Editor.
alter table public.profiles add column if not exists gender text;
alter table public.profiles drop constraint if exists profiles_gender_check;
alter table public.profiles add constraint profiles_gender_check
  check (gender is null or gender in ('female','male','other'));

-- Cada usuario solo puede actualizar su propio perfil mediante las políticas RLS existentes.
