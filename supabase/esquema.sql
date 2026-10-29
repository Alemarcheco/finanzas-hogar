-- =============================================================
-- Finanzas del Hogar: tablas y permisos para Supabase
-- Pega todo este texto en Supabase > SQL Editor y pulsa "Run".
-- Se puede ejecutar más de una vez sin problema.
-- =============================================================

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

-- Planificación: lo previsto para cada mes ------------------------------
create table if not exists public.planes (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mes date not null,
  tipo text not null check (tipo in ('ingreso', 'gasto', 'ahorro')),
  categoria text not null,
  monto numeric(14, 2) not null,
  nota text not null default '',
  creado_en timestamptz not null default now()
);
create index if not exists planes_hogar_mes_idx on public.planes(hogar_id, mes);

-- Tarjetas de crédito, préstamos y otras deudas -------------------------
create table if not exists public.deudas (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  -- Persona responsable de la deuda
  usuario_id uuid not null references auth.users(id) on delete cascade,
  nombre text not null,
  tipo text not null default 'tarjeta' check (tipo in ('tarjeta', 'prestamo', 'otra')),
  limite numeric(14, 2),
  saldo_inicial numeric(14, 2) not null default 0,
  dia_pago int check (dia_pago between 1 and 31),
  creado_en timestamptz not null default now()
);
create index if not exists deudas_hogar_idx on public.deudas(hogar_id);

-- Pagos a la deuda y cargos que no se anotaron como gasto ------------------
create table if not exists public.operaciones_deuda (
  id uuid primary key default gen_random_uuid(),
  hogar_id uuid not null references public.hogares(id) on delete cascade,
  deuda_id uuid not null references public.deudas(id) on delete cascade,
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('cargo', 'pago')),
  monto numeric(14, 2) not null,
  nota text not null default '',
  fecha date not null default current_date,
  creado_en timestamptz not null default now()
);
create index if not exists operaciones_deuda_hogar_idx on public.operaciones_deuda(hogar_id);

-- Un gasto pagado con tarjeta suma a la deuda de esa tarjeta
alter table public.movimientos
  add column if not exists deuda_id uuid references public.deudas(id) on delete set null;

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
  for insert with check (
    hogar_id = public.mi_hogar() and usuario_id = auth.uid()
    and (deuda_id is null or exists (select 1 from public.deudas d where d.id = deuda_id and d.hogar_id = public.mi_hogar()))
  );
drop policy if exists "editar mis movimientos" on public.movimientos;
create policy "editar mis movimientos" on public.movimientos
  for update using (usuario_id = auth.uid())
  with check (
    hogar_id = public.mi_hogar() and usuario_id = auth.uid()
    and (deuda_id is null or exists (select 1 from public.deudas d where d.id = deuda_id and d.hogar_id = public.mi_hogar()))
  );
drop policy if exists "borrar mis movimientos" on public.movimientos;
create policy "borrar mis movimientos" on public.movimientos
  for delete using (usuario_id = auth.uid());

alter table public.planes enable row level security;
alter table public.deudas enable row level security;
alter table public.operaciones_deuda enable row level security;

-- El plan y las deudas los pueden ver y cambiar todos los del hogar
drop policy if exists "plan del hogar" on public.planes;
create policy "plan del hogar" on public.planes
  for all using (hogar_id = public.mi_hogar()) with check (hogar_id = public.mi_hogar());

drop policy if exists "deudas del hogar" on public.deudas;
create policy "deudas del hogar" on public.deudas
  for all using (hogar_id = public.mi_hogar())
  with check (
    hogar_id = public.mi_hogar()
    and exists (select 1 from public.miembros where usuario_id = deudas.usuario_id and hogar_id = public.mi_hogar())
  );

drop policy if exists "operaciones de deudas del hogar" on public.operaciones_deuda;
create policy "operaciones de deudas del hogar" on public.operaciones_deuda
  for all using (hogar_id = public.mi_hogar())
  with check (
    hogar_id = public.mi_hogar()
    and exists (select 1 from public.deudas d where d.id = deuda_id and d.hogar_id = public.mi_hogar())
  );

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
    -- gen_random_uuid() es de Postgres; no depende de extensiones.
    v_codigo := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
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

-- Cargar una copia de seguridad (archivo .json exportado desde la app) -------
-- Añade al hogar actual lo que falte; lo que ya existe (mismo id) no se toca,
-- así que cargar dos veces la misma copia no duplica nada.
-- Cada cosa se asigna a la misma persona si sigue en el hogar (por id o por
-- nombre); si no, a quien carga la copia.
create or replace function public.importar_copia(p_copia jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_hogar uuid := public.mi_hogar();
  v_mapa jsonb := '{}';
  v_usuario uuid;
  r jsonb;
  n_deudas int; n_movimientos int; n_planes int; n_operaciones int;
begin
  if auth.uid() is null or v_hogar is null then
    raise exception 'Hay que pertenecer a un hogar';
  end if;
  if p_copia->>'app' is distinct from 'finanzas-hogar' then
    raise exception 'Este archivo no es una copia de Finanzas del Hogar';
  end if;

  -- Personas de la copia -> personas del hogar actual
  for r in select * from jsonb_array_elements(coalesce(p_copia->'miembros', '[]'))
  loop
    select m.usuario_id into v_usuario from miembros m
      where m.hogar_id = v_hogar
        and (m.usuario_id::text = r->>'usuario_id' or lower(trim(m.nombre)) = lower(trim(r->>'nombre')))
      order by (m.usuario_id::text = r->>'usuario_id') desc
      limit 1;
    v_mapa := v_mapa || jsonb_build_object(r->>'usuario_id', coalesce(v_usuario, auth.uid()));
  end loop;
  select v_mapa || coalesce(jsonb_object_agg(usuario_id::text, usuario_id), '{}') into v_mapa
    from miembros where hogar_id = v_hogar;

  insert into deudas (id, hogar_id, usuario_id, nombre, tipo, limite, saldo_inicial, dia_pago)
  select (x->>'id')::uuid, v_hogar,
         coalesce((v_mapa->>(x->>'usuario_id'))::uuid, auth.uid()),
         x->>'nombre', coalesce(x->>'tipo', 'otra'), (x->>'limite')::numeric,
         coalesce((x->>'saldo_inicial')::numeric, 0), (x->>'dia_pago')::int
    from jsonb_array_elements(coalesce(p_copia->'deudas', '[]')) x
  on conflict (id) do nothing;
  get diagnostics n_deudas = row_count;

  insert into movimientos (id, hogar_id, usuario_id, tipo, categoria, monto, nota, fecha, deuda_id)
  select (x->>'id')::uuid, v_hogar,
         coalesce((v_mapa->>(x->>'usuario_id'))::uuid, auth.uid()),
         x->>'tipo', x->>'categoria', (x->>'monto')::numeric, coalesce(x->>'nota', ''), (x->>'fecha')::date,
         (select d.id from deudas d where d.id::text = x->>'deuda_id' and d.hogar_id = v_hogar)
    from jsonb_array_elements(coalesce(p_copia->'movimientos', '[]')) x
  on conflict (id) do nothing;
  get diagnostics n_movimientos = row_count;

  insert into planes (id, hogar_id, usuario_id, mes, tipo, categoria, monto, nota)
  select (x->>'id')::uuid, v_hogar, auth.uid(), (x->>'mes')::date, x->>'tipo', x->>'categoria',
         (x->>'monto')::numeric, coalesce(x->>'nota', '')
    from jsonb_array_elements(coalesce(p_copia->'planes', '[]')) x
  on conflict (id) do nothing;
  get diagnostics n_planes = row_count;

  insert into operaciones_deuda (id, hogar_id, deuda_id, usuario_id, tipo, monto, nota, fecha)
  select (x->>'id')::uuid, v_hogar, d.id,
         coalesce((v_mapa->>(x->>'usuario_id'))::uuid, auth.uid()),
         x->>'tipo', (x->>'monto')::numeric, coalesce(x->>'nota', ''), (x->>'fecha')::date
    from jsonb_array_elements(coalesce(p_copia->'operaciones_deuda', '[]')) x
    join deudas d on d.id::text = x->>'deuda_id' and d.hogar_id = v_hogar
  on conflict (id) do nothing;
  get diagnostics n_operaciones = row_count;

  return jsonb_build_object(
    'movimientos', n_movimientos, 'planes', n_planes, 'deudas', n_deudas, 'operaciones', n_operaciones
  );
end;
$$;

grant execute on function public.mi_hogar() to authenticated;
grant execute on function public.crear_hogar(text, text, text) to authenticated;
grant execute on function public.unirse_hogar(text, text) to authenticated;
grant execute on function public.salir_hogar() to authenticated;
grant execute on function public.importar_copia(jsonb) to authenticated;

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
  begin
    alter publication supabase_realtime add table public.planes;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.deudas;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.operaciones_deuda;
  exception when duplicate_object then null;
  end;
end $$;
