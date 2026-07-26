-- Accept the compact final-summary display fields while keeping already
-- persisted legacy summaries readable. Runtime validation remains the
-- authoritative deep content/provenance boundary.

create or replace function public.material_analysis_valid_summary_payload(
  p_value jsonb
)
returns boolean
language sql
immutable
set search_path = pg_catalog, public
as $$
  select p_value is not null
    and pg_catalog.jsonb_typeof(p_value) = 'object'
    and pg_catalog.octet_length(p_value::text) <= 1048576
    and pg_catalog.length(p_value->>'language') between 1 and 32
    and pg_catalog.jsonb_typeof(p_value->'sections') = 'array'
    and pg_catalog.jsonb_typeof(p_value->'key_concepts') = 'array'
    and pg_catalog.jsonb_typeof(p_value->'equations') = 'array'
    and pg_catalog.jsonb_array_length(p_value->'equations') <= 100
    and public.material_analysis_safe_warnings_v2(p_value->'warnings')
    and pg_catalog.jsonb_typeof(p_value->'partial_extraction') = 'object'
    and (
      (
        p_value ?& array[
          'language','sections','key_concepts','equations','warnings',
          'partial_extraction'
        ]
        and (
          p_value - array[
            'language','sections','key_concepts','equations','warnings',
            'partial_extraction'
          ]
        ) = '{}'::jsonb
        and pg_catalog.jsonb_array_length(p_value->'sections')
          between 1 and 24
        and pg_catalog.jsonb_array_length(p_value->'key_concepts') <= 50
      )
      or
      (
        p_value ?& array[
          'language','overview_markdown','topic_titles','sections',
          'key_concepts','equations','warnings','partial_extraction'
        ]
        and (
          p_value - array[
            'language','overview_markdown','topic_titles','sections',
            'key_concepts','equations','warnings','partial_extraction'
          ]
        ) = '{}'::jsonb
        and pg_catalog.jsonb_typeof(p_value->'overview_markdown') = 'string'
        and pg_catalog.length(p_value->>'overview_markdown') between 1 and 1200
        and pg_catalog.cardinality(pg_catalog.regexp_split_to_array(
          pg_catalog.btrim(p_value->>'overview_markdown'),
          E'\\n[[:space:]]*\\n'
        )) between 2 and 4
        and (p_value->>'overview_markdown') !~*
          E'(page|pages|seite|seiten|страница|страницы|стр\\.)[[:space:]]*[0-9]'
        and pg_catalog.jsonb_typeof(p_value->'topic_titles') = 'array'
        and pg_catalog.jsonb_array_length(p_value->'topic_titles')
          between 3 and 8
        and not exists (
          select 1
          from pg_catalog.jsonb_array_elements(p_value->'topic_titles')
            as topic(value)
          where pg_catalog.jsonb_typeof(topic.value) <> 'string'
            or pg_catalog.length(pg_catalog.btrim(topic.value #>> '{}'))
              not between 1 and 80
            or topic.value #>> '{}' <> pg_catalog.btrim(topic.value #>> '{}')
        )
        and (
          select pg_catalog.count(distinct pg_catalog.lower(
            pg_catalog.btrim(topic.value)
          ))
          from pg_catalog.jsonb_array_elements_text(p_value->'topic_titles')
            as topic(value)
        ) = pg_catalog.jsonb_array_length(p_value->'topic_titles')
        and pg_catalog.jsonb_array_length(p_value->'sections')
          between 1 and 6
        and pg_catalog.jsonb_array_length(p_value->'key_concepts') <= 12
      )
    )
$$;

do $$
begin
  if (
    select proowner
    from pg_catalog.pg_proc
    where oid =
      'public.material_analysis_valid_summary_payload(jsonb)'::regprocedure
  ) <> 'postgres'::regrole then
    raise exception 'unexpected_compact_summary_contract_owner';
  end if;
end
$$;
