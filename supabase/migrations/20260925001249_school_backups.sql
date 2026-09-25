-- Cloud backups are immutable snapshots. The iOS client validates the full
-- SchoolState model before upload and after download; this constraint keeps
-- obviously malformed or oversized payloads out of the backup history.
create table public.school_backups (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    state jsonb not null,
    created_at timestamptz not null default now(),
    constraint school_backups_state_v1_check check (
        jsonb_typeof(state) = 'object'
        and state ?& array[
            'schemaVersion',
            'students',
            'courses',
            'lessons',
            'assignments',
            'attendance',
            'activities'
        ]
        and jsonb_typeof(state -> 'schemaVersion') = 'number'
        and state ->> 'schemaVersion' = '1'
        and jsonb_typeof(state -> 'students') = 'array'
        and jsonb_typeof(state -> 'courses') = 'array'
        and jsonb_typeof(state -> 'lessons') = 'array'
        and jsonb_typeof(state -> 'assignments') = 'array'
        and jsonb_typeof(state -> 'attendance') = 'array'
        and jsonb_typeof(state -> 'activities') = 'array'
        and octet_length(state::text) <= 10485760
    )
);

-- Supports the app's owner-scoped, newest-first backup history and makes the
-- auth.users ON DELETE CASCADE efficient.
create index school_backups_user_id_created_at_idx
    on public.school_backups (user_id, created_at desc);

alter table public.school_backups enable row level security;

-- The Data API is intentionally unavailable to unauthenticated callers. An
-- authenticated anonymous session also has the authenticated database role,
-- so each policy explicitly rejects its JWT claim.
revoke all on table public.school_backups from anon;
revoke update on table public.school_backups from authenticated;
grant select, insert, delete on table public.school_backups to authenticated;
grant all on table public.school_backups to service_role;

create policy "Users can read their own non-anonymous backups"
    on public.school_backups
    for select
    to authenticated
    using (
        (select auth.uid()) = user_id
        and (select auth.jwt() ->> 'is_anonymous') = 'false'
    );

create policy "Users can create their own non-anonymous backups"
    on public.school_backups
    for insert
    to authenticated
    with check (
        (select auth.uid()) = user_id
        and (select auth.jwt() ->> 'is_anonymous') = 'false'
    );

create policy "Users can delete their own non-anonymous backups"
    on public.school_backups
    for delete
    to authenticated
    using (
        (select auth.uid()) = user_id
        and (select auth.jwt() ->> 'is_anonymous') = 'false'
    );
