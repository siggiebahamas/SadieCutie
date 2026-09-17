-- Nifti initial schema
-- Generated from Nifti_Sept17.html's top-level JS data structures.
-- Run this in Supabase Dashboard -> SQL Editor, or via `supabase db push` / MCP once connected.

-- ============ TENANCY ============

create table businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('buyer','supplier')),
  created_at timestamptz not null default now()
);

-- Links one buyer business to one supplier business. This is the join table
-- purchase_orders, price_agreements, conversations, and rfqs all hang off of.
create table business_relationships (
  id uuid primary key default gen_random_uuid(),
  buyer_business_id uuid not null references businesses(id),
  supplier_business_id uuid not null references businesses(id),
  category text,
  score integer,
  tier text,
  payment_terms text,
  preferred_contact text,
  country text,
  location text,
  credit_limit numeric,
  relationship_since date,
  created_at timestamptz not null default now(),
  unique (buyer_business_id, supplier_business_id)
);

-- ============ ORDERS ============

create table purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text not null unique,
  buyer_business_id uuid not null references businesses(id),
  supplier_business_id uuid not null references businesses(id),
  type text not null default 'local',
  status text not null,
  currency text not null default 'PHP',
  tax_rate numeric not null default 0,
  line_items jsonb not null default '[]',
  created_date date not null,
  requested_delivery_date date,
  delivery_address text,
  notes text,
  shipping jsonb,
  customs jsonb,
  invoice jsonb,
  counter jsonb,
  delivery_confirmation jsonb,
  at_risk boolean not null default false,
  risk_note text,
  history jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on purchase_orders (buyer_business_id);
create index on purchase_orders (supplier_business_id);

-- ============ INVENTORY (buyer-side stock) ============

create table inventory_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  sku_code text not null,
  name text not null,
  warehouse text,
  on_hand numeric not null default 0,
  rop numeric,
  max_level numeric,
  lot text,
  exp date,
  status text,
  supplier_name text,
  days_left integer,
  lead_time integer,
  batches jsonb not null default '[]',
  barcode text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, sku_code)
);

-- ============ SUPPLY (supplier-side sellable stock) ============

create table supply_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  sku_code text not null,
  name text not null,
  location text,
  on_hand numeric not null default 0,
  committed numeric not null default 0,
  restock_level numeric,
  barcode text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, sku_code)
);

-- ============ DOWNSTREAM (a buyer's own sales to their own customers) ============

create table downstream_customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  name text not null,
  contact_name text,
  phone text,
  address text,
  terms text,
  created_date date,
  created_at timestamptz not null default now()
);

create table downstream_sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  customer_id uuid not null references downstream_customers(id),
  sale_date date not null,
  line_items jsonb not null default '[]',
  payments jsonb not null default '[]',
  created_at timestamptz not null default now()
);
create index on downstream_sales (customer_id);

-- ============ TEAM ============

create table team_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  name text not null,
  email text,
  roles text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index on team_members (business_id);

-- ============ CATALOG (a supplier's own product listing) ============

create table catalog_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  product text not null,
  price numeric,
  unit text,
  moq numeric,
  photo_url text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index on catalog_items (business_id);

-- catalog_public lives on businesses, not its own table (see judgment calls below).
alter table businesses add column catalog_public boolean not null default false;

-- ============ AUDIT LOG ============

create table audit_log (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  action text not null,
  entity_type text,
  entity_id text,
  field text,
  old_value jsonb,
  new_value jsonb,
  actor text,
  occurred_at timestamptz not null default now()
);
create index on audit_log (business_id, occurred_at desc);

-- ============ NOTIFICATION SETTINGS ============

create table notification_settings (
  business_id uuid primary key references businesses(id),
  order_updates boolean not null default true,
  price_changes boolean not null default true,
  new_messages boolean not null default true,
  weekly_summary boolean not null default false,
  lead_alerts boolean not null default true,
  channel_viber boolean not null default true,
  channel_sms boolean not null default false,
  channel_whatsapp boolean not null default false,
  channel_email boolean not null default false,
  sms_number text,
  email_address text
);
