-- Preserve the original trusted batch operation when a claimed work unit is
-- relabeled as reconciliation. Provider input payloads remain unchanged.

create or replace function public.material_analysis_work_payload(
  p_batch_id uuid,p_lease_token uuid
) returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare v_batch public.material_processing_batches%rowtype; v_job public.material_processing_jobs%rowtype;
  v_payload jsonb; v_key text;
begin
  select * into v_batch from public.material_processing_batches
  where id=p_batch_id and lease_token=p_lease_token;
  if not found then raise exception 'work_lease_invalid'; end if;
  select * into v_job from public.material_processing_jobs where id=v_batch.job_id;
  select a.idempotency_key into v_key from public.material_processing_attempts a
    where a.id=v_batch.current_attempt_id;
  if v_batch.operation='page_text' then
    select jsonb_build_object('pages',jsonb_agg(jsonb_build_object(
      'page_number',p.page_number,'normalized_text',p.normalized_text) order by p.page_number))
    into v_payload from public.material_processing_pages p
    where p.job_id=v_batch.job_id and p.page_number=any(v_batch.page_numbers);
  elsif v_batch.operation in ('page_visual','page_recovery') then
    v_payload := jsonb_build_object('operation',v_batch.operation,'page_numbers',to_jsonb(v_batch.page_numbers));
  elsif v_batch.operation='reduction' then
    if cardinality(v_batch.input_batch_ids)>0 then
      select jsonb_build_object('inputs',jsonb_agg(b.result_payload->'content' order by b.created_at),
        'equation_ids',coalesce(jsonb_agg(b.result_payload->'content'->'equation_ids'),'[]'::jsonb))
      into v_payload from public.material_processing_batches b where b.id=any(v_batch.input_batch_ids);
    else
      select jsonb_build_object('inputs',jsonb_agg(p.result_payload order by p.page_number),
        'equation_ids',coalesce(jsonb_agg(p.result_payload->'equations'),'[]'::jsonb))
      into v_payload from public.material_processing_pages p where p.job_id=v_batch.job_id
        and p.page_number=any(v_batch.page_numbers) and p.status in ('completed','partial');
    end if;
  else
    select jsonb_build_object(
      'operation','final_summary','validated_reduction',top.result_payload->'content',
      'manifest',jsonb_agg(jsonb_build_object('page_number',p.page_number,'status',p.status,
        'route',p.route,'warnings',p.warning_payload) order by p.page_number))
    into v_payload from public.material_processing_batches top
    join public.material_processing_pages p on p.job_id=top.job_id
    where top.id=v_batch.input_batch_ids[1] group by top.result_payload;
  end if;
  return jsonb_build_object('kind',v_batch.operation,'operation',v_batch.operation,
    'material_id',v_batch.material_id,'job_id',v_batch.job_id,'batch_id',v_batch.id,
    'lease_token',p_lease_token,'idempotency_key',v_key,'page_count',v_job.page_count,
    'page_numbers',to_jsonb(v_batch.page_numbers),'input_payload',coalesce(v_payload,'{}'::jsonb),
    'response_id',v_batch.upstream_response_id,'temporary_file_id',v_batch.temporary_file_id);
end
$$;

alter function public.material_analysis_work_payload(uuid,uuid) owner to postgres;
revoke all on function public.material_analysis_work_payload(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.material_analysis_work_payload(uuid,uuid)
  to service_role;
