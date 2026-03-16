# Supabase Security Hardening

## What Was Removed From Code

- Hardcoded public Supabase URL and anon key were removed from Flutter runtime paths.
- Hardcoded backend fallback values for `SUPABASE_URL` and `SUPABASE_ANON_KEY` were removed.
- Maintenance upload scripts now require environment-provided credentials.
- Direct Google tile usage was removed from the mobile map layer.

## Runtime Configuration

Preferred order for backend environment loading:

1. `SOOBSHIO_ENV_FILE`
2. `%USERPROFILE%/.soobshio/runtime.env`
3. `.env.runtime`
4. local `.env` as development fallback

For Flutter, public Supabase runtime config is loaded from backend `/config` and persisted locally.

## Required Supabase Tables/Buckets To Audit

- `reports`
- `infographic_data`
- `complaints`
- bucket `reports-media`

## Minimum RLS Policy Baseline

### `reports`

- `select`: allow anonymous read only for public/open records actually intended for map display
- `insert`: only authenticated backend/service role, or tightly validated anon inserts through Edge Function/backend
- `update`: deny anonymous direct updates except explicitly designed counters, and even then prefer RPC/backend
- `delete`: service role only

### `complaints`

- `select`: scoped to complaint owner/admin only, unless complaint is intentionally public
- `insert`: allow only validated client payloads, ideally through backend instead of direct table writes
- `update`: owner or admin only
- `delete`: owner or admin only

### `infographic_data`

- `select`: allow public read only if the data is intentionally public
- `insert/update/delete`: service role only

### Storage bucket `reports-media`

- `select`: public only if files are intentionally public
- `insert`: restrict object path pattern and MIME type
- `update/delete`: owner or service role only

## Suggested SQL Review Checklist

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('reports', 'complaints', 'infographic_data');

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('reports', 'complaints', 'infographic_data')
order by tablename, policyname;
```

```sql
select id, name, public
from storage.buckets
where id in ('reports-media');

select policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;
```

## Recommended Direction

- Move anonymous writes behind backend or Edge Functions.
- Keep direct client access read-only wherever possible.
- Use `SUPABASE_SERVICE_ROLE_KEY` only on backend/maintenance scripts, never in Flutter.
