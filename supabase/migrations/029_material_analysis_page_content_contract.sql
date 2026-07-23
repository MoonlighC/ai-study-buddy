-- Persist the explicit Phase C page-content status and closed warning contract.
-- Provider-facing v2 page payloads are normalized to the already persisted v1
-- content shape; terminal status remains authoritative in the page row.

create or replace function public.material_analysis_safe_warnings_v2(p_value jsonb)
returns boolean
language sql
immutable
set search_path = pg_catalog, public
as $$
  select public.material_analysis_safe_warnings(p_value)
    and not exists (
      select 1
      from pg_catalog.jsonb_array_elements(p_value) as warning(value)
      where warning.value->>'code' not in (
        'page_content_partial',
        'page_content_missing',
        'source_metadata_omitted',
        'page_missing',
        'invalid_equation_latex'
      )
    )
$$;

create or replace function public.complete_material_analysis_operation_internal(
  p_batch_id uuid,
  p_lease_token uuid,
  p_validated_result jsonb,
  p_validation_version text,
  p_validation_hash text,
  p_summary_markdown text default null,
  p_cleanup_complete boolean default true
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_batch public.material_processing_batches%rowtype;
  v_page jsonb;
  v_persisted_page jsonb;
  v_status text;
begin
  select * into v_batch
  from public.material_processing_batches
  where id=p_batch_id and lease_token=p_lease_token
  for update;
  if not found then raise exception 'operation_completion_conflict'; end if;

  if v_batch.operation in ('page_text','page_visual','page_recovery') then
    if jsonb_typeof(p_validated_result->'pages') <> 'array'
      or jsonb_array_length(p_validated_result->'pages') <> cardinality(v_batch.page_numbers)
    then raise exception 'invalid_page_batch_result'; end if;

    for v_page in
      select value from jsonb_array_elements(p_validated_result->'pages')
    loop
      v_status := v_page->>'content_status';
      if v_status not in ('completed','partial','missing')
        or (v_page->>'trustworthy')::boolean is not true
        or not public.material_analysis_safe_warnings_v2(v_page->'warnings')
        or (v_status='completed' and exists (
          select 1 from jsonb_array_elements(v_page->'warnings') as warning(value)
            where warning.value->>'code' in ('page_content_partial','page_content_missing')
        ))
        or (v_status='partial' and not exists (
          select 1 from jsonb_array_elements(v_page->'warnings') as warning(value)
            where warning.value->>'code'='page_content_partial'
        ))
        or (v_status='missing' and (
          coalesce(v_page->>'summary_markdown','') <> ''
          or jsonb_array_length(v_page->'key_concepts') <> 0
          or jsonb_array_length(v_page->'equations') <> 0
          or (v_page->>'confidence')::numeric <> 0
          or not exists (
            select 1 from jsonb_array_elements(v_page->'warnings') as warning(value)
              where warning.value->>'code'='page_content_missing'
          )
        ))
      then raise exception 'invalid_page_content_contract'; end if;

      v_persisted_page := case
        when v_status='missing' then null
        else v_page - 'content_status'
      end;
      perform public.complete_material_processing_page_internal(
        v_batch.job_id,
        (v_page->>'page_number')::integer,
        p_lease_token,
        v_status,
        v_persisted_page,
        v_page->'warnings',
        p_validation_version,
        encode(extensions.digest(v_page::text,'sha256'),'hex')
      );
    end loop;
    perform public.complete_material_processing_batch_internal(
      p_batch_id,
      p_lease_token,
      jsonb_build_object(
        'schema_version',1,
        'operation',v_batch.operation,
        'content',p_validated_result
      ),
      p_validation_version,
      p_validation_hash
    );
  elsif v_batch.operation='reduction' then
    if not public.material_analysis_safe_warnings_v2(p_validated_result->'warnings')
      then raise exception 'invalid_analysis_warning_code'; end if;
    perform public.complete_material_processing_batch_internal(
      p_batch_id,
      p_lease_token,
      jsonb_build_object(
        'schema_version',1,
        'operation','reduction',
        'content',p_validated_result
      ),
      p_validation_version,
      p_validation_hash
    );
  else
    if not public.material_analysis_safe_warnings_v2(p_validated_result->'warnings')
      then raise exception 'invalid_analysis_warning_code'; end if;
    perform public.finalize_material_processing_job_internal(
      v_batch.job_id,
      p_lease_token,
      p_validated_result,
      p_summary_markdown,
      p_validation_version,
      p_validation_hash
    );
  end if;

  if v_batch.temporary_file_id is not null then
    update public.material_processing_artifacts
    set state='cleanup_pending',lease_token=null,lease_expires_at=null,
      cleanup_retry_after=null,updated_at=now()
    where batch_id=p_batch_id and state='uploaded';
  end if;
end
$$;

alter function public.material_analysis_safe_warnings_v2(jsonb) owner to postgres;
alter function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) owner to postgres;

revoke all on function public.material_analysis_safe_warnings_v2(jsonb)
  from public,anon,authenticated,service_role;
revoke all on function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) from public,anon,authenticated;
grant execute on function public.complete_material_analysis_operation_internal(
  uuid,uuid,jsonb,text,text,text,boolean
) to service_role;

notify pgrst,'reload schema';
