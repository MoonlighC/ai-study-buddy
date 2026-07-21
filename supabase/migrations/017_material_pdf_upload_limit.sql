-- Raise the authoritative PDF upload ceiling to exactly 40 MiB. Images retain
-- their independent 8 MiB limit.

update storage.buckets
set file_size_limit = 41943040
where id = 'study-materials';

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
        and file_size_bytes between 1 and 41943040
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
          and file_size_bytes between 1 and 41943040
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
  'Upload metadata and user/material path mapping. PDFs are limited to exactly 40 MiB; images retain the independent 8 MiB limit.';
