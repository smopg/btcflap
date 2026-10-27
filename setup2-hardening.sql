-- HODL Flap: extra protection. Run once in Supabase SQL Editor after setup.sql.

-- 1. Names: letters, numbers, spaces, - and _ only (no links, dots or symbols)
alter table public.scores drop constraint if exists scores_name_clean;
alter table public.scores add constraint scores_name_clean
  check (name ~ '^[A-Za-z0-9 _-]{1,16}$') not valid;

-- 2. Guard every new score: block scam words and rude names, stop spam
create or replace function public.scores_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.name := btrim(new.name);
  new.created_at := now();
  if lower(new.name) ~ '(airdrop|claim|giveaway|admin|official|support|wallet|seed|http|www|telegram|discord|whatsapp|fuck|shit|cunt|bitch|nigg|fagg|rape|nazi|hitler)' then
    raise exception 'name not allowed';
  end if;
  if exists (select 1 from public.scores
             where name = new.name and created_at > now() - interval '10 seconds') then
    raise exception 'too fast';
  end if;
  if (select count(*) from public.scores
      where created_at > now() - interval '1 minute') > 200 then
    raise exception 'too busy';
  end if;
  return new;
end;
$$;

drop trigger if exists scores_guard on public.scores;
create trigger scores_guard
  before insert on public.scores
  for each row execute function public.scores_guard();

-- 3. Belt and braces: the public can only read and add, never change or delete
revoke update, delete, truncate on public.scores from anon, authenticated;
revoke insert, update, delete, truncate on public.leaderboard from anon, authenticated;
revoke all on function public.scores_guard() from anon, authenticated;
