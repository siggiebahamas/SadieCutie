-- Nifti schema, part 2
-- Everything from collectNiftiPersistableState() (Nifti_Sept17.html:17292) not covered in
-- supabase_schema.sql. Depends on businesses, team_members, and purchase_orders from part 1 —
-- run supabase_schema.sql first if you haven't.

-- ============ MESSAGING ============
-- buyerConversations + supplierConversations were the same thread read from each side;
-- one conversation per (buyer, supplier) pair, with unread counts kept per side.

create table conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_business_id uuid not null references businesses(id),
  supplier_business_id uuid not null references businesses(id),
  buyer_unread_count integer not null default 0,
  supplier_unread_count integer not null default 0,
  created_at timestamptz not null default now(),
  unique (buyer_business_id, supplier_business_id)
);

create table conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id),
  sender_business_id uuid not null references businesses(id),
  text text not null,
  sent_at timestamptz not null default now(),
  po_id uuid references purchase_orders(id),
  attachment jsonb
);
create index on conversation_messages (conversation_id, sent_at);

-- ============ PRICE AGREEMENTS ============
-- standingPriceAgreements + deletedPriceAgreements folded into one table with deleted_at
-- (soft delete) instead of physically moving rows between two arrays.

create table price_agreements (
  id uuid primary key default gen_random_uuid(),
  buyer_business_id uuid not null references businesses(id),
  supplier_business_id uuid not null references businesses(id),
  product text not null,
  price numeric not null,
  unit text,
  effective_date date,
  end_date date,
  note text,
  status text not null default 'confirmed',
  attachment_name text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
create index on price_agreements (buyer_business_id, supplier_business_id);

-- ============ SUPPLIER INBOX ============

create table supplier_inbox (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  type text not null,
  pill_label text,
  pill_class text,
  title text not null,
  meta text,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
create index on supplier_inbox (business_id, resolved);

-- ============ CUSTOM ROLES ============

create table custom_roles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  name text not null,
  allowed_pages text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (business_id, name)
);

-- ============ IN-APP NOTIFICATIONS ============
-- (the feed itself — distinct from notification_settings, which is preferences)

create table notifications (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  text text not null,
  color text,
  read boolean not null default false,
  action jsonb,
  created_at timestamptz not null default now()
);
create index on notifications (business_id, read);

-- ============ RFQs ============

create table rfqs (
  id uuid primary key default gen_random_uuid(),
  rfq_number text not null unique,
  buyer_business_id uuid not null references businesses(id),
  supplier_business_id uuid not null references businesses(id),
  items jsonb not null default '[]',
  needed_by_date date,
  notes text,
  status text not null default 'sent',
  quote jsonb,
  history jsonb not null default '[]',
  created_at timestamptz not null default now()
);

-- ============ TAX PROFILES ============
-- One row per business (was keyed by role 'buyer'/'supplier' in the single-user demo — a real
-- business is itself either a buyer account, a supplier account, or both, so business_id as the
-- key covers all three cases).

create table tax_profiles (
  business_id uuid primary key references businesses(id),
  business_name text,
  tin text,
  rdo_code text,
  registered_address text,
  vat_status text,
  reg_type text,
  reg_number text,
  reg_valid_until date,
  next_si_number integer not null default 1,
  next_dr_number integer not null default 1,
  next_cn_number integer not null default 1
);

-- ============ TEAM: TASKS, ACTIVITY, CHAT ============

create table team_tasks (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  title text not null,
  assigned_to uuid references team_members(id),
  created_by uuid references team_members(id),
  due_date date,
  status text not null default 'open',
  acknowledged_at timestamptz,
  created_at timestamptz not null default now()
);

create table team_activity_log (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  actor text,
  action text not null,
  kind text,
  occurred_at timestamptz not null default now()
);

create table team_chat_messages (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  author text,
  text text not null,
  sent_at timestamptz not null default now()
);

-- ============ SUPPORT ============

create table support_messages (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  category text not null,
  message text not null,
  from_name text,
  created_at timestamptz not null default now()
);

-- ============ BILLING / SUBSCRIPTION ============

create table subscriptions (
  business_id uuid primary key references businesses(id),
  plan_id text not null default 'starter',
  billing_cycle text not null default 'monthly',
  status text not null default 'active',
  trial_ends_at date,
  started_at date not null default current_date,
  cancelled_at date,
  has_used_trial boolean not null default false,
  billing_history jsonb not null default '[]'
);

-- ============ REFERRALS ============

create table referrals (
  business_id uuid primary key references businesses(id),
  code text unique
);

create table referral_invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  invited_name text not null,
  joined_date date,
  created_at timestamptz not null default now()
);

-- ============ ANALYTICS / PUSH / DISCOVERY LOGS ============

create table analytics_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  name text not null,
  properties jsonb not null default '{}',
  occurred_at timestamptz not null default now()
);
create index on analytics_events (business_id, occurred_at desc);

create table push_log (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  channel text not null,
  event_type text,
  text text,
  read boolean not null default false,
  undeliverable boolean not null default false,
  occurred_at timestamptz not null default now()
);

create table discovery_leads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  direction text not null,
  for_role text not null,
  counterpart_name text,
  category text,
  status text not null default 'new',
  lead_date date,
  created_at timestamptz not null default now()
);

create table reminder_log (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  po_id uuid references purchase_orders(id),
  reminder_date date,
  occurred_at timestamptz not null default now()
);

-- ============ DISMISSED ITEMS ============
-- dismissedInsightKeys + NIFTI_DISMISSED_ISSUE_IDS unified: both are just "ids this business
-- dismissed," distinguished only by which kind of thing they point at.

create table dismissed_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  kind text not null check (kind in ('insight','issue')),
  item_key text not null,
  dismissed_at timestamptz not null default now(),
  unique (business_id, kind, item_key)
);

-- ============ DATA IMPORT / EXPLORE ============

create table import_batches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  type text not null,
  filename text,
  imported_at date,
  actor text,
  row_count integer,
  added_codes jsonb not null default '[]',
  updated_snapshots jsonb not null default '[]',
  rolled_back boolean not null default false,
  created_at timestamptz not null default now()
);

create table saved_explore_views (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  name text not null,
  filter jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- ============ SKU OVERRIDES ============

create table sku_overrides (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id),
  norm_name text not null,
  criticality_tier text,
  criticality_reason text,
  criticality_overridden_at timestamptz,
  criticality_overridden_by text,
  backup_supplier_id uuid references businesses(id),
  unique (business_id, norm_name)
);
