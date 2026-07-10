-- Phase 9A: private PDF/image upload foundation.
-- This migration does not create buckets or process file contents.

do $$
begin
  if not exists (select 1 from storage.buckets where id = 'study-materials') then
    raise exception 'Required private bucket study-materials is missing';
  end if;
  if not exists (select 1 from storage.buckets where id = 'study-images') then
    raise exception 'Required private bucket study-images is missing';
  end if;
end
$$;

update storage.buckets
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array['application/pdf']::text[]
where id = 'study-materials';

update storage.buckets
set public = false,
    file_size_limit = 8388608,
    allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp']::text[]
where id = 'study-images';

-- Repository migrations 001-003 define no storage.objects policies. Before
-- applying this migration, run the documented pg_policies preflight and stop
-- if any separately-created policy can grant access to study-materials or
-- study-images. Permissive PostgreSQL policies combine with OR, so unknown
-- policies cannot be safely neutralized by replacing only the names below.

drop policy if exists "Phase 9A users insert own study uploads" on storage.objects;
create policy "Phase 9A users insert own study uploads"
on storage.objects for insert
to authenticated
with check (
  bucket_id in ('study-materials', 'study-images')
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and btrim(storage.filename(name)) <> ''
);

drop policy if exists "Phase 9A users read own study uploads" on storage.objects;
create policy "Phase 9A users read own study uploads"
on storage.objects for select
to authenticated
using (
  bucket_id in ('study-materials', 'study-images')
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and btrim(storage.filename(name)) <> ''
);

drop policy if exists "Phase 9A users delete own study uploads" on storage.objects;
create policy "Phase 9A users delete own study uploads"
on storage.objects for delete
to authenticated
using (
  bucket_id in ('study-materials', 'study-images')
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and coalesce(array_length(storage.foldername(name), 1), 0) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and btrim(storage.filename(name)) <> ''
);

alter table public.materials
drop constraint if exists materials_upload_shape;

alter table public.materials
add constraint materials_upload_shape check (
  source_kind <> 'upload'
  or (
    kind in ('pdf', 'image')
    and storage_bucket is not null
    and storage_path is not null
    and file_size_bytes is not null
    and split_part(storage_path, '/', 1) = user_id::text
    and split_part(storage_path, '/', 2) = id::text
    and split_part(storage_path, '/', 3) <> ''
    and split_part(storage_path, '/', 4) = ''
    and (
      (
        kind = 'pdf'
        and storage_bucket = 'study-materials'
        and mime_type = 'application/pdf'
        and file_size_bytes between 1 and 10485760
      )
      or (
        kind = 'image'
        and storage_bucket = 'study-images'
        and mime_type in ('image/png', 'image/jpeg', 'image/webp')
        and file_size_bytes between 1 and 8388608
      )
    )
  )
);

drop policy if exists "Users can insert own materials" on public.materials;
create policy "Users can insert own materials"
on public.materials for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and user_id = (select auth.uid())
  and (
    source_kind <> 'upload'
    or (
      kind in ('pdf', 'image')
      and content_text is null
      and summary is null
      and processing_status = 'pending'
      and storage_bucket is not null
      and storage_path is not null
      and split_part(storage_path, '/', 1) = (select auth.uid())::text
      and split_part(storage_path, '/', 2) = id::text
      and split_part(storage_path, '/', 3) <> ''
      and split_part(storage_path, '/', 4) = ''
      and (
        (
          kind = 'pdf'
          and storage_bucket = 'study-materials'
          and mime_type = 'application/pdf'
          and file_size_bytes between 1 and 10485760
        )
        or (
          kind = 'image'
          and storage_bucket = 'study-images'
          and mime_type in ('image/png', 'image/jpeg', 'image/webp')
          and file_size_bytes between 1 and 8388608
        )
      )
    )
  )
);

comment on constraint materials_upload_shape on public.materials is
  'Phase 9A upload metadata and user/material path mapping. Future extraction and OCR backends must revalidate the actual file format server-side before processing.';
