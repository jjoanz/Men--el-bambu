-- ============================================================================
-- El Bambú · esquema de base de datos (Postgres)
-- Se ejecuta como el usuario dueño de la base (bambu). Es seguro repetirlo.
--   psql "$DATABASE_URL" -f db/schema.sql
-- ============================================================================

-- Categoría = una sección del menú.
--   screen : pantalla del menú donde aparece
--   tab    : solo 'bebidas'; las categorías con la misma pestaña se agrupan
--            (si es null, la pestaña se llama como la categoría)
--   layout : 'cards' = tarjetas con foto · 'list' = lista simple nombre + precio
create table if not exists categories (
  id         integer generated always as identity primary key,
  name       text    not null check (length(btrim(name)) > 0),
  screen     text    not null check (screen in ('entradas', 'principales', 'postres', 'bebidas')),
  tab        text,
  layout     text    not null default 'cards' check (layout in ('cards', 'list')),
  sort       integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists products (
  id          uuid primary key default gen_random_uuid(),
  category_id integer not null references categories (id) on delete cascade,
  name        text    not null check (length(btrim(name)) > 0),
  description text    not null default '',
  price       numeric(10, 2) not null default 0 check (price >= 0),
  image_url   text,                       -- 'img/menu/x.jpeg' (repo) o '/uploads/x.jpg' (subida desde el panel)
  available   boolean not null default true,   -- false = "Agotado"
  visible     boolean not null default true,   -- false = oculto del menú público
  sort        integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists products_category_idx on products (category_id);

-- Usuarios del panel y sesiones (el token viaja en una cookie; aquí solo se guarda su hash)
create table if not exists admin_users (
  id            integer generated always as identity primary key,
  username      text not null,
  password_hash text not null,
  created_at    timestamptz not null default now()
);
create unique index if not exists admin_users_username_key on admin_users (lower(username));

create table if not exists sessions (
  token_hash text primary key,
  user_id    integer not null references admin_users (id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists sessions_expires_idx on sessions (expires_at);

create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists products_touch on products;
create trigger products_touch before update on products
  for each row execute function touch_updated_at();
