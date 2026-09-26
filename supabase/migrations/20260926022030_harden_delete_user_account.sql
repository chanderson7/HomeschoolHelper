-- Prevent object resolution through a caller-controlled search path while the
-- account deletion RPC runs with the function owner's privileges.
alter function public.delete_user_account()
set search_path = '';
