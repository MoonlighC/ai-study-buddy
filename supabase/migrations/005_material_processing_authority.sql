-- Phase 9B: extraction lifecycle and summaries are server-authoritative.
-- Existing SELECT, INSERT, and DELETE privileges and policies are unchanged.

revoke update on table public.materials
from public, anon, authenticated;

drop policy if exists "Users can update own materials" on public.materials;

comment on table public.materials is
  'User-owned study materials. Direct client UPDATE is disabled; trusted server code owns extraction lifecycle and summary writes.';
