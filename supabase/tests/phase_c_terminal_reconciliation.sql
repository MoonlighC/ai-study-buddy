\set ON_ERROR_STOP on

create or replace function pg_temp.assert_terminal_reconciliation(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'terminal_reconciliation_assertion_failed: %',message;
  end if;
end
$$;

insert into auth.users(id,email) values
  ('18181818-1818-4818-8818-181818181818','terminal-reconciliation@example.test');

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '18181818-1818-4818-8818-181818181801',
  '18181818-1818-4818-8818-181818181818',
  'Terminal reconciliation fixture','pdf','upload','study-materials',
  '18181818-1818-4818-8818-181818181818/18181818-1818-4818-8818-181818181801/source.pdf',
  'application/pdf',128,'pending','{}'
);

do $$
declare
  v_job uuid; v_work jsonb; v_batch uuid; v_lease uuid;
begin
  v_job:=public.prepare_material_analysis_internal(
    '18181818-1818-4818-8818-181818181801','recommended',false,1,repeat('a',64),
    '[{"page_number":1,"route":"text","normalized_text":"Readable page.","routing_signals":{"router_version":"phase-c-router-v1"},"routing_confidence":0.9,"input_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]'
  );
  v_work:=public.claim_next_material_analysis_operation_internal(
    '18181818-1818-4818-8818-181818181801');
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_terminal_12345678',null);

  perform public.terminalize_material_analysis_operation_internal(
    v_batch,v_lease,'terminal_structured_output_invalid');

  perform pg_temp.assert_terminal_reconciliation(
    (select status='failed' and failure_code='structured_output_invalid'
      and budget_state='released' and lease_token is null
      and completed_at is not null
      from public.material_processing_batches where id=v_batch),
    'batch leaves reconciliation as a released terminal failure');
  perform pg_temp.assert_terminal_reconciliation(
    (select status='failed' and failure_code='structured_output_invalid'
      and budget_effect='released' and completed_at is not null
      from public.material_processing_attempts
      where id=(select current_attempt_id from public.material_processing_batches
        where id=v_batch)),
    'attempt receives bounded safe failure classification');
  perform pg_temp.assert_terminal_reconciliation(
    (select status='failed' and safe_error_code='structured_output_invalid'
      and budget_state='released' and active_lease_token is null
      and completed_at is not null
      from public.material_processing_jobs where id=v_job),
    'job leaves pending with no active provider lease');
  perform pg_temp.assert_terminal_reconciliation(
    (select processing_status='failed' from public.materials
      where id='18181818-1818-4818-8818-181818181801'),
    'material publishes terminal failure');

  perform set_config(
    'request.jwt.claim.sub','18181818-1818-4818-8818-181818181818',true);
  perform pg_temp.assert_terminal_reconciliation(
    (select state='failed'
      and safe_error_code='structured_output_invalid'
      and active_operation is null
      from public.get_material_analysis_status(
        '18181818-1818-4818-8818-181818181801')),
    'Flutter projection exposes only the safe terminal classification');
end
$$;

delete from public.materials
where id='18181818-1818-4818-8818-181818181801';
delete from auth.users where id='18181818-1818-4818-8818-181818181818';
