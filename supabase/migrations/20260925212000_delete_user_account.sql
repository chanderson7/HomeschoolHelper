-- Allows authenticated users to securely delete their own account and all associated cloud data.
-- This function runs with security definer privileges so it can delete the user from auth.users.
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
as $$
declare
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    -- Explicitly remove user cloud backups
    delete from public.school_backups where user_id = current_user_id;

    -- Delete user record from auth.users (cascades any remaining auth foreign keys)
    delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_user_account() from public, anon;
grant execute on function public.delete_user_account() to authenticated;
