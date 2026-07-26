create or replace function pg_temp.assert_compact_summary(
  value boolean,
  message text
)
returns void
language plpgsql
as $$
begin
  if value is distinct from true then
    raise exception 'compact_summary_assertion_failed: %', message;
  end if;
end
$$;

select pg_temp.assert_compact_summary(
  public.material_analysis_valid_summary_payload(
    '{
      "language":"en",
      "overview_markdown":"A compact document overview.\n\nIt connects the main topics without page narration.",
      "topic_titles":["State machines","Registers","Counters"],
      "sections":[{
        "id":"overview",
        "title":"Overview",
        "blocks":[{"kind":"prose","markdown":"Detailed analysis.","display":"block"}],
        "source_pages":[1],
        "confidence":0.9
      }],
      "key_concepts":[],
      "equations":[],
      "warnings":[],
      "partial_extraction":{
        "is_partial":false,
        "analyzed_pages":[1],
        "partial_pages":[],
        "missing_pages":[],
        "page_modes":[{"page":1,"mode":"text"}]
      }
    }'::jsonb
  ),
  'compact summary is accepted'
);

select pg_temp.assert_compact_summary(
  not public.material_analysis_valid_summary_payload(
    jsonb_set(
      '{
        "language":"en",
        "overview_markdown":"First paragraph.\n\nSecond paragraph.",
        "topic_titles":["One","Two","Three"],
        "sections":[{
          "id":"overview",
          "title":"Overview",
          "blocks":[{"kind":"prose","markdown":"Detail.","display":"block"}],
          "source_pages":[1],
          "confidence":0.9
        }],
        "key_concepts":[],
        "equations":[],
        "warnings":[],
        "partial_extraction":{
          "is_partial":false,
          "analyzed_pages":[1],
          "partial_pages":[],
          "missing_pages":[],
          "page_modes":[{"page":1,"mode":"text"}]
        }
      }'::jsonb,
      '{topic_titles}',
      '["One","one","Three"]'::jsonb
    )
  ),
  'duplicate topics are rejected'
);

select pg_temp.assert_compact_summary(
  not public.material_analysis_valid_summary_payload(
    jsonb_set(
      '{
        "language":"en",
        "overview_markdown":"First paragraph.\n\nSecond paragraph.",
        "topic_titles":["One","Two","Three"],
        "sections":[{
          "id":"overview",
          "title":"Overview",
          "blocks":[{"kind":"prose","markdown":"Detail.","display":"block"}],
          "source_pages":[1],
          "confidence":0.9
        }],
        "key_concepts":[],
        "equations":[],
        "warnings":[],
        "partial_extraction":{
          "is_partial":false,
          "analyzed_pages":[1],
          "partial_pages":[],
          "missing_pages":[],
          "page_modes":[{"page":1,"mode":"text"}]
        }
      }'::jsonb,
      '{key_concepts}',
      (
        select jsonb_agg(jsonb_build_object(
          'title','Concept ' || value,
          'explanation_markdown','Detail.',
          'source_pages',jsonb_build_array(1),
          'confidence',0.9
        ))
        from generate_series(1,13) value
      )
    )
  ),
  'more than twelve final concepts are rejected'
);

-- Existing v1 rows remain readable during rollout.
select pg_temp.assert_compact_summary(
  public.material_analysis_valid_summary_payload(
    '{
      "language":"en",
      "sections":[{
        "id":"legacy",
        "title":"Legacy",
        "blocks":[{"kind":"prose","markdown":"Legacy detail.","display":"block"}],
        "source_pages":[1],
        "confidence":0.9
      }],
      "key_concepts":[],
      "equations":[],
      "warnings":[],
      "partial_extraction":{
        "is_partial":false,
        "analyzed_pages":[1],
        "partial_pages":[],
        "missing_pages":[],
        "page_modes":[{"page":1,"mode":"text"}]
      }
    }'::jsonb
  ),
  'legacy summary remains accepted'
);
