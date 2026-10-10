-- =====================================================================
-- Kalender Akademik Madrasah - setup database (Supabase)
-- Jalankan SEKALI: Supabase > SQL Editor > New query > tempel > Run
-- =====================================================================

-- 1. Tabel kegiatan
create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  title       text    not null,
  cat         text    not null check (cat in ('libur','belajar','ujian','pondok','kegiatan','admin')),
  start_date  date    not null,
  end_date    date    not null,
  time_text   text,
  place       text,
  note        text,
  aud         text[]  not null default '{santri,guru,wali,pengelola}',
  blok        boolean not null default false,
  approx      boolean not null default false,
  rep         boolean not null default false,
  until_date  date,
  created_at  timestamptz not null default now(),
  constraint events_dates_ok check (end_date >= start_date)
);
create index if not exists events_start_idx on public.events (start_date);

-- 2. Pengaturan madrasah (satu baris saja)
create table if not exists public.settings (
  id   int  primary key check (id = 1),
  name text not null,
  ta   text not null,
  pola int  not null check (pola in (5,6))
);
insert into public.settings (id, name, ta, pola)
values (1, 'Madrasah Aliyah Pesantren, Yogyakarta', '2026/2027', 6)
on conflict (id) do nothing;

-- 3. Daftar pengelola (hanya akun di tabel ini yang boleh mengubah data)
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- 4. Fungsi cek pengelola
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

-- 5. Keamanan (Row Level Security)
alter table public.events   enable row level security;
alter table public.settings enable row level security;
alter table public.admins   enable row level security;

drop policy if exists events_read   on public.events;
drop policy if exists events_write  on public.events;
drop policy if exists settings_read  on public.settings;
drop policy if exists settings_write on public.settings;
drop policy if exists admins_self    on public.admins;

-- siapa saja boleh MEMBACA
create policy events_read   on public.events   for select using (true);
create policy settings_read on public.settings for select using (true);

-- hanya pengelola boleh MENGUBAH
create policy events_write on public.events
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy settings_write on public.settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- pengguna login hanya bisa melihat barisnya sendiri di tabel admins
create policy admins_self on public.admins
  for select to authenticated using (user_id = auth.uid());

-- =====================================================================
-- 6. JADIKAN AKUN PENGELOLA
-- Buat user dulu di Authentication > Users > Add user, lalu jalankan
-- (ganti emailnya) sebagai query terpisah:
--
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'email.pengelola@contoh.sch.id';
-- =====================================================================
