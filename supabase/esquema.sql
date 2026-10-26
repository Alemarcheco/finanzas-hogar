-- =============================================================
-- Finanzas del Hogar: tablas y permisos para Supabase
-- Pega todo este texto en Supabase > SQL Editor y pulsa "Run".
-- Se puede ejecutar más de una vez sin problema.
-- =============================================================

create extension if not exists pgcrypto;

-- Hogares --------------------------------------------------------
create table if not exists public.hogares (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  codigo text not null unique,
  moneda text not null default '$',
  creado_por uuid references auth.users(id) on delete set null,
  creado_en timestamptz not null default now()
);

-- Miembros (cada usuario pertenece a un solo hogar) ---------------
create table if not exists public.miembros (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  nombre text not null,
  unido_en timestamptz not null default now()
);
create index if not exists miembros_hogar_idx on public.miembros(hogar_id);

-- Movimientos: ingresos, gastos y ahorro ---------------------------
create table if not exists public.movimientos (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('ingreso', 'gasto', 'ahorro')),
  categoria text not null,
  monto numeric(14, 2) not null,
  nota text not null default '',
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);
create index if not exists movimientos_hogar_fecha_idx on public.movimientos(hogar_id, fecha);

-- Hogar del usuario que hace la consulta ---------------------------
create or replace function public.mi_hogar()
returns uuid
language sql stable security definer set search_path = public
as $$
  select hogar_id from public.miembros where usuario_id = auth.uid()
$$;

-- Permisos (Row Level Security) -------------------------------------
alter table public.hogares enable row level security;
alter table public.miembros enable row level security;
alter table public.movimientos enable row level security;

drop policy if exists "ver mi hogar" on public.hogares;
create policy "ver mi hogar" on public.hogares
  for select using (id = public.mi_hogar());
drop policy if exists "editar mi hogar" on public.hogares;
create policy "editar mi hogar" on public.hogares
  for update using (id = public.mi_hogar());

drop policy if exists "ver miembros de mi hogar" on public.miembros;
create policy "ver miembros de mi hogar" on public.miembros
  for select using (hogar_id = public.mi_hogar());
drop policy if exists "editar mi nombre" on public.miembros;
create policy "editar mi nombre" on public.miembros
  for update using (usuario_id = auth.uid()) with check (hogar_id = public.mi_hogar());

drop policy if exists "ver movimientos del hogar" on public.movimientos;
create policy "ver movimientos del hogar" on public.movimientos
  for select using (hogar_id = public.mi_hogar());
drop policy if exists "anotar mis movimientos" on public.movimientos;
create policy "anotar mis movimientos" on public.movimientos
  for insert with check (hogar_id = public.mi_hogar() and usuario_id = auth.uid());
drop policy if exists "editar mis movimientos" on public.movimientos;
create policy "editar mis movimientos" on public.movimientos
  for update using (usuario_id = auth.uid())
  with check (hogar_id = public.mi_hogar() and usuario_id = auth.uid());
drop policy if exists "borrar mis movimientos" on public.movimientos;
create policy "borrar mis movimientos" on public.movimientos
  for delete using (usuario_id = auth.uid());

-- Crear un hogar nuevo ---------------------------------------------
create or replace function public.crear_hogar(p_nombre text, p_moneda text, p_mi_nombre text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
  v_codigo text;
begin
  if auth.uid() is null then
    raise exception 'Hay que iniciar sesión';
  end if;
  if exists (select 1 from miembros where usuario_id = auth.uid()) then
    raise exception 'Ya perteneces a un hogar';
  end if;
  loop
    v_codigo := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 6));
    exit when not exists (select 1 from hogares where codigo = v_codigo);
  end loop;
  insert into hogares (nombre, codigo, moneda, creado_por)
    values (p_nombre, v_codigo, coalesce(nullif(p_moneda, ''), '$'), auth.uid())
    returning id into v_id;
  insert into miembros (usuario_id, hogar_id, nombre) values (auth.uid(), v_id, p_mi_nombre);
  return v_id;
end;
$$;

-- Unirse a un hogar con su código ------------------------------------
create or replace function public.unirse_hogar(p_codigo text, p_mi_nombre text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Hay que iniciar sesión';
  end if;
  if exists (select 1 from miembros where usuario_id = auth.uid()) then
    raise exception 'Ya perteneces a un hogar';
  end if;
  select id into v_id from hogares where codigo = upper(trim(p_codigo));
  if v_id is null then
    raise exception 'No existe ningún hogar con ese código';
  end if;
  insert into miembros (usuario_id, hogar_id, nombre) values (auth.uid(), v_id, p_mi_nombre);
  return v_id;
end;
$$;

-- Salir del hogar (los movimientos que anotaste se quedan en el hogar) -
create or replace function public.salir_hogar()
returns void
language sql security definer set search_path = public
as $$
  delete from miembros where usuario_id = auth.uid();
$$;

grant execute on function public.mi_hogar() to authenticated;
grant execute on function public.crear_hogar(text, text, text) to authenticated;
grant execute on function public.unirse_hogar(text, text) to authenticated;
grant execute on function public.salir_hogar() to authenticated;

-- Actualización en vivo: lo que anota uno aparece al momento en el otro teléfono
do $$
begin
  begin
    alter publication supabase_realtime add table public.movimientos;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.miembros;
  exception when duplicate_object then null;
  end;
end $$;
