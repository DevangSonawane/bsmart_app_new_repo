-- Suggested Supabase migrations / RPCs for atomic operations

-- Increment views atomically
/*
create function increment_views(post_id uuid)
returns void language plpgsql as $$
begin
  update posts set views_count = coalesce(views_count,0) + 1 where id = post_id;
end;
$$;
*/

-- Ad events table for analytics
/*
create table ad_events (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id),
  ad_id uuid references ads(id),
  event_type text not null, -- view, click, complete
  metadata jsonb,
  created_at timestamptz default now()
);
*/

-- Device tokens table for FCM tokens
/*
create table device_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id),
  token text not null,
  platform text,
  created_at timestamptz default now()
);
*/

