-- Flutter ARGB color values such as 0xFF16A34A exceed PostgreSQL integer range.
alter table public.subjects
alter column color_value type bigint;
