-- GOVI notifications: friendship requests, accepted friendships, likes, comments and followers.
create table if not exists public.govi_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('friend_request','friend_accepted','like','comment','follow')),
  post_id uuid,
  comment_id uuid,
  friendship_id uuid references public.govi_friendships(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists govi_notifications_recipient_created
  on public.govi_notifications(recipient_id, created_at desc);
create index if not exists govi_notifications_unread
  on public.govi_notifications(recipient_id) where read_at is null;
alter table public.govi_notifications enable row level security;
drop policy if exists "GOVI users read own notifications" on public.govi_notifications;
create policy "GOVI users read own notifications"
  on public.govi_notifications for select to authenticated using (recipient_id=auth.uid());
drop policy if exists "GOVI users mark own notifications read" on public.govi_notifications;
create policy "GOVI users mark own notifications read"
  on public.govi_notifications for update to authenticated
  using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());

create or replace function public.govi_notify_friendship()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' and new.status='pending' and new.requester_id<>new.addressee_id then
    insert into public.govi_notifications(recipient_id,actor_id,type,friendship_id)
    values(new.addressee_id,new.requester_id,'friend_request',new.id);
  elsif tg_op='UPDATE' and old.status is distinct from new.status and new.status='accepted' then
    insert into public.govi_notifications(recipient_id,actor_id,type,friendship_id)
    values(new.requester_id,new.addressee_id,'friend_accepted',new.id);
  end if;
  return new;
end; $$;
drop trigger if exists govi_friendship_notification_trigger on public.govi_friendships;
create trigger govi_friendship_notification_trigger
after insert or update of status on public.govi_friendships
for each row execute function public.govi_notify_friendship();

create or replace function public.govi_notify_like()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id=new.post_id;
  if owner_id is not null and owner_id<>new.user_id then
    insert into public.govi_notifications(recipient_id,actor_id,type,post_id)
    values(owner_id,new.user_id,'like',new.post_id);
  end if;
  return new;
end; $$;
drop trigger if exists govi_like_notification_trigger on public.post_likes;
create trigger govi_like_notification_trigger after insert on public.post_likes
for each row execute function public.govi_notify_like();

create or replace function public.govi_notify_comment()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid;
begin
  select user_id into owner_id from public.posts where id=new.post_id;
  if owner_id is not null and owner_id<>new.user_id then
    insert into public.govi_notifications(recipient_id,actor_id,type,post_id,comment_id)
    values(owner_id,new.user_id,'comment',new.post_id,new.id);
  end if;
  return new;
end; $$;
drop trigger if exists govi_comment_notification_trigger on public.post_comments;
create trigger govi_comment_notification_trigger after insert on public.post_comments
for each row execute function public.govi_notify_comment();

create or replace function public.govi_notify_follow()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.follower_id<>new.followed_id then
    insert into public.govi_notifications(recipient_id,actor_id,type)
    values(new.followed_id,new.follower_id,'follow');
  end if;
  return new;
end; $$;
drop trigger if exists govi_follow_notification_trigger on public.govi_follows;
create trigger govi_follow_notification_trigger after insert on public.govi_follows
for each row execute function public.govi_notify_follow();
