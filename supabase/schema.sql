-- HD-1 Drop Monitor - Supabase schema
--
-- Reconstructed on 2026-11-17 from the live production database (PostgREST OpenAPI:
-- table/column names, types, defaults, NOT NULL, primary and foreign keys) and from the
-- application code (upsert conflict keys, enum values, delete behaviour).
--
-- Idempotent: safe to run on an empty database or re-run on an existing one. It never drops
-- tables or data. Run it in the Supabase SQL editor (or psql) as the postgres role.
--
-- The application talks to these tables server-side only, through PostgREST with the
-- service-role key, which bypasses row-level security. RLS is enabled with no policies so
-- the public anon key cannot read or write any of this data.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------------------------
-- Types

do $$
begin
  if not exists (select 1 from pg_type where typname = 'eventpulse_monitor_status') then
    create type public.eventpulse_monitor_status as enum (
      'available', 'monitoring', 'captcha', 'limited', 'paused'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------------------------
-- Global Controls & Settings (single row, id = true)

create table if not exists public.eventpulse_settings (
  id boolean primary key default true check (id),
  refresh_seconds integer not null default 4,
  sound_alerts boolean not null default true,
  push_alerts boolean not null default true,
  sms_alerts boolean not null default false,
  whatsapp_alerts boolean not null default false,
  telegram_alerts boolean not null default false,
  discord_alerts boolean not null default false,
  multilogin_endpoint text not null default 'http://localhost:35462',
  multilogin_state_policy text not null default 'save_profile_state_on_user_action',
  auto_rotate_proxy_on_rate_limit boolean not null default false,
  maintain_sticky_mobile_ip boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.eventpulse_settings
  add column if not exists telegram_alerts boolean not null default false,
  add column if not exists discord_alerts boolean not null default false,
  add column if not exists auto_rotate_proxy_on_rate_limit boolean not null default false,
  add column if not exists maintain_sticky_mobile_ip boolean not null default true;

insert into public.eventpulse_settings (id) values (true) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------------------------
-- Multilogin profiles (profile_name is the key targets and sessions refer to)

create table if not exists public.eventpulse_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_name text not null unique,
  region text not null default '',
  cookies_status text not null default 'Unknown',
  session_status text not null default 'Not Captured',
  fingerprint_health text not null default 'Unknown',
  multilogin_profile_id text,
  multilogin_folder_id text,
  sticky_ip_label text,
  last_session_saved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.eventpulse_profiles
  add column if not exists multilogin_folder_id text;

create table if not exists public.eventpulse_profile_sessions (
  id uuid primary key default gen_random_uuid(),
  profile_name text not null
    references public.eventpulse_profiles (profile_name) on update cascade on delete cascade,
  state_label text not null default 'Latest saved state',
  session_state jsonb not null,
  restore_policy text not null default 'manual_restore',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Monitor targets

create table if not exists public.eventpulse_targets (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  event_name text not null,
  venue text not null default '',
  target_url text not null,
  status public.eventpulse_monitor_status not null default 'monitoring',
  availability text not null default 'No inventory detected',
  refresh_seconds numeric not null default 5,
  profile_name text not null default '',
  proxy_label text not null default 'Unassigned',
  section_filters text[] not null default '{}',
  min_tickets integer not null default 2,
  max_price numeric,
  normal_tickets_only boolean not null default true,
  even_ticket_quantities_only boolean not null default false,
  monitor_starts_at timestamptz,
  monitor_ends_at timestamptz,
  deep_link text not null default '',
  last_checked_at timestamptz,
  last_response_ms integer,
  last_status_code integer,
  last_error text,
  last_available_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.eventpulse_targets
  add column if not exists even_ticket_quantities_only boolean not null default false,
  add column if not exists monitor_starts_at timestamptz,
  add column if not exists monitor_ends_at timestamptz;

-- The scheduler loads non-paused targets, oldest check first.
create index if not exists eventpulse_targets_due_idx
  on public.eventpulse_targets (last_checked_at nulls first)
  where status <> 'paused';

-- ---------------------------------------------------------------------------------------------
-- Alert log and per-channel delivery audit

create table if not exists public.eventpulse_alerts (
  id uuid primary key default gen_random_uuid(),
  -- Deleting a target keeps its alert history.
  target_id uuid references public.eventpulse_targets (id) on delete set null,
  tone text not null default 'info',
  message text not null,
  deep_link text,
  delivered_push boolean not null default false,
  delivered_sms boolean not null default false,
  delivered_whatsapp boolean not null default false,
  delivered_telegram boolean not null default false,
  delivered_discord boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.eventpulse_alerts
  add column if not exists delivered_telegram boolean not null default false,
  add column if not exists delivered_discord boolean not null default false;

create index if not exists eventpulse_alerts_created_at_idx
  on public.eventpulse_alerts (created_at desc);

-- ---------------------------------------------------------------------------------------------
-- Browser push subscriptions (upserted on endpoint)

create table if not exists public.eventpulse_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  endpoint text not null unique,
  subscription jsonb not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Row-level security: service role only

alter table public.eventpulse_settings enable row level security;
alter table public.eventpulse_profiles enable row level security;
alter table public.eventpulse_profile_sessions enable row level security;
alter table public.eventpulse_targets enable row level security;
alter table public.eventpulse_alerts enable row level security;
alter table public.eventpulse_push_subscriptions enable row level security;
