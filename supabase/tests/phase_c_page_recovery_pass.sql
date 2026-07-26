\set ON_ERROR_STOP on

create or replace function pg_temp.assert_page_recovery(
  value boolean,
  message text
) returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'page_recovery_assertion_failed: %',message;
  end if;
end
$$;

insert into auth.users(id,email) values (
  '33333333-3333-4333-8333-333333333333',
  'page-recovery@example.test'
);

insert into public.materials(
  id,user_id,title,kind,source_kind,storage_bucket,storage_path,mime_type,
  file_size_bytes,processing_status,metadata
) values (
  '33333333-3333-4333-8333-333333333301',
  '33333333-3333-4333-8333-333333333333',
  'Bounded page recovery','pdf','upload','study-materials',
  '33333333-3333-4333-8333-333333333333/33333333-3333-4333-8333-333333333301/source.pdf',
  'application/pdf',128,'pending','{}'
);

do $$
declare
  v_job uuid;
  v_contract jsonb;
  v_fingerprint text;
  v_work jsonb;
  v_batch uuid;
  v_lease uuid;
  v_plan jsonb;
  v_manifest jsonb;
  v_recovery_page integer;
  v_result jsonb;
  v_initial_page_one jsonb;
  v_initial_page_two jsonb;
  v_diagnostics jsonb;
  v_page_snapshot jsonb;
begin
  v_contract:=jsonb_build_object(
    'fingerprint_version','phase-c-fingerprint-v2',
    'source_content_hash',repeat('a',64),
    'source_metadata_hash',repeat('b',64),
    'processing_mode','recommended',
    'page_count',6,
    'router_version','phase-c-router-v1',
    'prompt_version','phase-c-prompts-v3',
    'page_schema_version','phase-c-page-schema-v3',
    'reduction_schema_version','phase-c-reduction-schema-v2',
    'final_summary_schema_version','phase-c-final-schema-v3',
    'validator_version','phase-c-validator-v3',
    'openai_configuration_version','phase-c-server-v2',
    'mini_pdf_version','phase-c-mini-pdf-v1'
  );
  v_fingerprint:=
    public.material_analysis_version_fingerprint(v_contract);
  select jsonb_agg(jsonb_build_object(
    'page_number',page_number,
    'route','visual',
    'normalized_text','Authoritative page text '||page_number::text,
    'routing_signals',jsonb_build_object(
      'router_version','phase-c-router-v1',
      'source_render_exists',true,
      'blank_page_conclusive',page_number=6
    ),
    'routing_confidence',0.9,
    'input_hash',repeat(to_hex(page_number),64)
  ) order by page_number)
  into v_plan
  from generate_series(1,6) page_number;

  v_job:=public.prepare_material_analysis_internal(
    '33333333-3333-4333-8333-333333333301',
    'recommended',false,6,repeat('a',64),v_contract,v_fingerprint,v_plan,false
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '33333333-3333-4333-8333-333333333301'
  );
  perform pg_temp.assert_page_recovery(
    v_work->>'kind'='page_visual'
      and v_work->'page_numbers'='[1,2,3,4,5]'::jsonb,
    'first initial batch is unchanged'
  );
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_initial_pages_12345',null
  );
  v_initial_page_one:=jsonb_build_object(
    'page_number',1,'content_status','missing','summary_markdown','',
    'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0,
    'warnings',jsonb_build_array(jsonb_build_object(
      'code','page_content_missing','detail','No usable grounded content.',
      'source_pages',jsonb_build_array(1)
    )),'trustworthy',true
  );
  v_initial_page_two:=v_initial_page_one
    || jsonb_build_object(
      'page_number',2,
      'warnings',jsonb_build_array(jsonb_build_object(
        'code','page_content_missing','detail','No usable grounded content.',
        'source_pages',jsonb_build_array(2)
      ))
    );
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    jsonb_build_object('pages',jsonb_build_array(
      v_initial_page_one,
      v_initial_page_two,
      v_initial_page_one
        || jsonb_build_object(
          'page_number',3,
          'warnings',jsonb_build_array(jsonb_build_object(
            'code','page_content_missing',
            'detail','No usable grounded content.',
            'source_pages',jsonb_build_array(3)
          ))
        ),
      jsonb_build_object(
        'page_number',4,'content_status','partial',
        'summary_markdown','Grounded partial page four.',
        'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0.4,
        'warnings',jsonb_build_array(jsonb_build_object(
          'code','page_content_partial','detail','Some content was unclear.',
          'source_pages',jsonb_build_array(4)
        )),'trustworthy',true
      ),
      jsonb_build_object(
        'page_number',5,'content_status','completed',
        'summary_markdown','Grounded completed page five.',
        'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0.9,
        'warnings','[]'::jsonb,'trustworthy',true
      )
    )),
    'phase-c-validator-v3',repeat('b',64),null,true
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '33333333-3333-4333-8333-333333333301'
  );
  perform pg_temp.assert_page_recovery(
    v_work->>'kind'='page_visual'
      and v_work->'page_numbers'='[6]'::jsonb,
    'second initial batch is unchanged'
  );
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_initial_page_6',null
  );
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    jsonb_build_object('pages',jsonb_build_array(
      v_initial_page_one
        || jsonb_build_object(
          'page_number',6,
          'warnings',jsonb_build_array(jsonb_build_object(
            'code','page_content_missing',
            'detail','No usable grounded content.',
            'source_pages',jsonb_build_array(6)
          ))
        )
    )),
    'phase-c-validator-v3',repeat('c',64),null,true
  );

  select jsonb_agg(to_jsonb(page) order by page.page_number)
  into v_page_snapshot
  from public.material_processing_pages page
  where page.job_id=v_job;

  v_diagnostics:=
    public.prepare_material_analysis_page_recoveries_internal(
      '33333333-3333-4333-8333-333333333301'
    );
  perform pg_temp.assert_page_recovery(
    v_diagnostics->>'recovery_candidate_count'='4'
      and v_diagnostics->>'recovery_duplicate_submission_count'='0'
      and (select count(*)=4
        and bool_and(cardinality(page_numbers)=1)
        and bool_and(max_attempts=1)
        from public.material_processing_batches
        where job_id=v_job and operation='page_recovery')
      and (select count(*)=4
        from public.material_processing_page_recoveries
        where job_id=v_job)
      and (select count(*)=0
        from public.material_processing_batches
        where job_id=v_job and operation='page_recovery'
          and (5=any(page_numbers) or 6=any(page_numbers))),
    'only missing and low-confidence nonblank pages are scheduled individually'
  );

  perform public.prepare_material_analysis_page_recoveries_internal(
    '33333333-3333-4333-8333-333333333301'
  );
  perform pg_temp.assert_page_recovery(
    (select count(*)=4
      from public.material_processing_batches
      where job_id=v_job and operation='page_recovery'),
    'relaunch does not duplicate recovery batches'
  );

  for v_recovery_page in 1..4 loop
    v_work:=public.claim_next_material_analysis_operation_internal(
      '33333333-3333-4333-8333-333333333301'
    );
    perform pg_temp.assert_page_recovery(
      v_work->>'kind'='page_recovery'
        and jsonb_array_length(v_work->'page_numbers')=1
        and (v_work->'page_numbers'->>0)::integer=v_recovery_page,
      'recovery claim preserves exact original page'
    );
    v_batch:=(v_work->>'batch_id')::uuid;
    v_lease:=(v_work->>'lease_token')::uuid;
    perform public.submit_material_analysis_operation_internal(
      v_batch,v_lease
    );
    perform public.record_material_analysis_response_internal(
      v_batch,v_lease,'resp_recovery_'||v_recovery_page::text||'_12345678',
      null
    );
    v_result:=case v_recovery_page
      when 1 then jsonb_build_object(
        'page_number',1,'content_status','completed',
        'summary_markdown','Recovered grounded page one.',
        'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0.9,
        'warnings','[]'::jsonb,'trustworthy',true
      )
      when 2 then jsonb_build_object(
        'page_number',2,'content_status','partial',
        'summary_markdown','Recovered grounded partial page two.',
        'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0.7,
        'warnings',jsonb_build_array(jsonb_build_object(
          'code','page_content_partial','detail','Some content remains unclear.',
          'source_pages',jsonb_build_array(2)
        )),'trustworthy',true
      )
      when 3 then v_initial_page_one
        || jsonb_build_object(
          'page_number',3,
          'warnings',jsonb_build_array(jsonb_build_object(
            'code','page_content_missing',
            'detail','No usable grounded content after recovery.',
            'source_pages',jsonb_build_array(3)
          ))
        )
      else jsonb_build_object(
        'page_number',4,'content_status','completed',
        'summary_markdown','Recovered grounded page four.',
        'key_concepts','[]'::jsonb,'equations','[]'::jsonb,'confidence',0.9,
        'warnings','[]'::jsonb,'trustworthy',true
      )
    end;
    perform public.complete_material_analysis_operation_internal(
      v_batch,v_lease,jsonb_build_object('pages',jsonb_build_array(v_result)),
      'phase-c-validator-v3',repeat(to_hex(v_recovery_page+10),64),
      null,true
    );
  end loop;

  perform pg_temp.assert_page_recovery(
    (select count(*)=4
      and count(distinct idempotency_key)=4
      from public.material_processing_attempts
      where job_id=v_job
        and batch_id in (
          select id from public.material_processing_batches
          where job_id=v_job and operation='page_recovery'
        ))
      and (select count(*)=0
        from public.material_processing_batches
        where job_id=v_job and operation='page_recovery'
          and attempt_count>1)
      and (select count(*)=4
        from public.material_processing_page_recoveries
        where job_id=v_job and reconciled_at is not null)
      and (select status='completed'
        and result_payload->>'summary_markdown'=
          'Grounded completed page five.'
        from public.material_processing_pages
        where job_id=v_job and page_number=5),
    'each recovery has one stable submission and completed page is unchanged'
  );

  perform pg_temp.assert_page_recovery(
    (select jsonb_agg(to_jsonb(page) order by page.page_number)
      from public.material_processing_pages page
      where page.job_id=v_job)=v_page_snapshot,
    'initial terminal page rows remain byte-for-byte immutable'
  );

  begin
    update public.material_processing_page_recoveries
    set result_validation_hash=repeat('f',64)
    where job_id=v_job and page_number=1;
    raise exception 'expected_terminal_recovery_immutable';
  exception
    when others then
      perform pg_temp.assert_page_recovery(
        sqlerrm like '%terminal_page_recovery_immutable%',
        'a stale request cannot overwrite a terminal recovery result'
      );
  end;

  v_work:=public.claim_next_material_analysis_operation_internal(
    '33333333-3333-4333-8333-333333333301'
  );
  perform pg_temp.assert_page_recovery(
    v_work->>'kind'='reduction'
      and v_work->'page_numbers'='[1,2,4,5]'::jsonb,
    'reduction uses the recovered authoritative manifest'
  );
  v_batch:=(v_work->>'batch_id')::uuid;
  v_lease:=(v_work->>'lease_token')::uuid;
  perform public.submit_material_analysis_operation_internal(v_batch,v_lease);
  perform public.record_material_analysis_response_internal(
    v_batch,v_lease,'resp_reduction_12345678',null
  );
  perform public.complete_material_analysis_operation_internal(
    v_batch,v_lease,
    jsonb_build_object(
      'source_pages',jsonb_build_array(1,2,4,5),
      'summary_markdown','Recovered reduction.',
      'key_concepts','[]'::jsonb,
      'equation_ids','[]'::jsonb,
      'warnings','[]'::jsonb,
      'confidence',0.8
    ),
    'phase-c-validator-v3',repeat('d',64),null,true
  );

  v_work:=public.claim_next_material_analysis_operation_internal(
    '33333333-3333-4333-8333-333333333301'
  );
  v_manifest:=v_work->'input_payload'->'manifest';
  perform pg_temp.assert_page_recovery(
    v_work->>'kind'='final_summary'
      and (select jsonb_agg(value->>'page_number' order by value->>'page_number')
        from jsonb_array_elements(v_manifest) value
        where value->>'status'='completed')='["1","4","5"]'::jsonb
      and (select jsonb_agg(value->>'page_number')
        from jsonb_array_elements(v_manifest) value
        where value->>'status'='partial')='["2"]'::jsonb
      and (select jsonb_agg(value->>'page_number' order by value->>'page_number')
        from jsonb_array_elements(v_manifest) value
        where value->>'status'='missing')='["3","6"]'::jsonb,
    'final summary receives recovered pages in the correct categories'
  );
end
$$;

delete from public.materials
where id='33333333-3333-4333-8333-333333333301';
delete from auth.users
where id='33333333-3333-4333-8333-333333333333';
