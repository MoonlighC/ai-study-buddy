-- Account deletion removes processing pages through foreign-key cascades. A
-- page DELETE must not refresh its parent job because that job is being
-- deleted by the same cascade and the Auth service correctly has no direct
-- processing-table privileges.

create or replace function public.refresh_material_processing_progress()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  update public.material_processing_jobs set
    completed_page_count = (
      select count(*) from public.material_processing_pages
      where job_id = new.job_id and status in ('completed','partial','missing')
    ),
    updated_at = now()
  where id = new.job_id;

  return new;
end
$$;

do $$
declare
  f regprocedure :=
    'public.refresh_material_processing_progress()'::regprocedure;
begin
  if current_user <> 'postgres' then
    raise exception 'unexpected_account_deletion_cascade_migration_owner';
  end if;

  execute format('alter function %s owner to postgres', f);
  execute format(
    'revoke all on function %s from public, anon, authenticated, service_role',
    f
  );
end
$$;
