-- Supabase schema for WOW Scales Verification System
-- Compatible with Postgres on Supabase
-- Run this in Supabase SQL editor

-- ============ Tables ============

-- Clients
create table if not exists public.clients (
  id bigserial primary key,
  client_name text not null,
  address text not null,
  phone text,
  email text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Verifications
create table if not exists public.verifications (
  id bigserial primary key,
  certificate_no text unique not null,
  verification_date date not null,
  verification_sticker text,
  client_id bigint references public.clients(id) on delete set null,
  status_type text check (status_type in ('initial','subsequent')) default 'initial',
  accuracy_type text check (accuracy_type in ('tolerance','error')) default 'tolerance',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Instruments
create table if not exists public.instruments (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  manufacturer text not null,
  model text not null,
  serial_number text not null,
  accuracy_class text check (accuracy_class in ('I','II','III','IIII')) default 'III',
  units text check (units in ('kg','g','mg','t','ct')) default 'kg',
  max_capacity double precision not null,
  max_test_load_available double precision,
  verification_interval_e double precision not null,
  min_capacity double precision,
  sa_number text,
  aa_number text,
  software_version text,
  sealing_method text,
  equipment_notes text,
  created_at timestamptz default now()
);

-- Accuracy tests
create table if not exists public.accuracy_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  test_load double precision,
  make_up text,
  indication double precision,
  run_up_load double precision,
  run_down_load double precision,
  switch_point_load double precision,
  error_value double precision,
  band text,
  mpe_value double precision,
  result text check (result in ('PASS','FAIL')),
  created_at timestamptz default now()
);

-- Variation tests
create table if not exists public.variation_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  applied_load text,
  reference_indication double precision,
  end1_indication double precision,
  middle_indication double precision,
  end2_indication double precision,
  created_at timestamptz default now()
);

-- Repeatability tests
create table if not exists public.repeatability_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  target_test_load double precision,
  run1_indication double precision,
  run2_indication double precision,
  run3_indication double precision,
  created_at timestamptz default now()
);

-- Zero tests
create table if not exists public.zero_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  test_type text check (test_type in ('semi_auto','auto_zero','zero_tracking')),
  delta_l_value double precision,
  result text check (result in ('PASS','FAIL','N/A')),
  created_at timestamptz default now()
);

-- Tare tests
create table if not exists public.tare_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  applied_tare double precision,
  indication double precision,
  error_value double precision,
  mpe_value double precision,
  result text check (result in ('PASS','FAIL')),
  created_at timestamptz default now()
);

-- Eccentricity tests
create table if not exists public.eccentricity_tests (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  position text,
  test_load double precision,
  indication double precision,
  error_value double precision,
  mpe_value double precision,
  result text check (result in ('PASS','FAIL')),
  created_at timestamptz default now()
);

-- Verification officers
create table if not exists public.verification_officers (
  id bigserial primary key,
  verification_id bigint references public.verifications(id) on delete cascade,
  officer_name text,
  officer_id text,
  sanas_lab_no text,
  seal_id text,
  signature text,
  created_at timestamptz default now()
);

-- ============ Indexes ============
create index if not exists idx_verifications_certificate_no on public.verifications(certificate_no);
create index if not exists idx_verifications_date on public.verifications(verification_date);
create index if not exists idx_verifications_client_id on public.verifications(client_id);
create index if not exists idx_instruments_verification_id on public.instruments(verification_id);
create index if not exists idx_accuracy_tests_verification_id on public.accuracy_tests(verification_id);
create index if not exists idx_clients_name on public.clients(client_name);

-- ============ Optional: updated_at trigger ============
-- Uncomment to auto-update updated_at columns on UPDATE
-- create extension if not exists "uuid-ossp";
-- create or replace function public.set_updated_at()
-- returns trigger as $$
-- begin
--   new.updated_at = now();
--   return new;
-- end;
-- $$ language plpgsql;
--
-- do $$ begin
--   if not exists (select 1 from pg_trigger where tgname = 'trg_clients_updated_at') then
--     create trigger trg_clients_updated_at before update on public.clients
--     for each row execute function public.set_updated_at();
--   end if;
--   if not exists (select 1 from pg_trigger where tgname = 'trg_verifications_updated_at') then
--     create trigger trg_verifications_updated_at before update on public.verifications
--     for each row execute function public.set_updated_at();
--   end if;
-- end $$;

-- ============ Optional: RLS & policies ============
-- Enable RLS (Row Level Security) if desired, then add policies.
-- alter table public.clients enable row level security;
-- alter table public.verifications enable row level security;
-- alter table public.instruments enable row level security;
-- alter table public.accuracy_tests enable row level security;
-- alter table public.variation_tests enable row level security;
-- alter table public.repeatability_tests enable row level security;
-- alter table public.zero_tests enable row level security;
-- alter table public.tare_tests enable row level security;
-- alter table public.eccentricity_tests enable row level security;
-- alter table public.verification_officers enable row level security;
--
-- Example policies (adjust as needed):
-- -- Read for anon
-- create policy anon_read_clients on public.clients for select to anon using (true);
-- create policy anon_read_verifications on public.verifications for select to anon using (true);
-- create policy anon_read_instruments on public.instruments for select to anon using (true);
-- create policy anon_read_accuracy on public.accuracy_tests for select to anon using (true);
-- create policy anon_read_variation on public.variation_tests for select to anon using (true);
-- create policy anon_read_repeatability on public.repeatability_tests for select to anon using (true);
-- create policy anon_read_zero on public.zero_tests for select to anon using (true);
-- create policy anon_read_tare on public.tare_tests for select to anon using (true);
-- create policy anon_read_eccentricity on public.eccentricity_tests for select to anon using (true);
-- create policy anon_read_officers on public.verification_officers for select to anon using (true);
--
-- -- Writes only via service role (skip policies; service_role bypasses RLS),
-- -- or create policies limited to service_role if you prefer explicit control.
