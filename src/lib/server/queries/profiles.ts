import type { SupabaseClient } from '@supabase/supabase-js';

export type ProfileRow = {
  id: string;
  display_name: string;
  email: string;
};

/**
 * Bulk fetch profiles by auth user ids.
 * Used everywhere that needs display_name/email for a set of user ids —
 * we cannot use Supabase JS embed because tenant_members.user_id → auth.users,
 * profiles.id → auth.users (indirect relationship).
 */
export async function fetchProfilesByIds(
  supabase: SupabaseClient,
  ids: (string | null | undefined)[]
): Promise<Map<string, ProfileRow>> {
  const uniq = Array.from(
    new Set(ids.filter((id): id is string => !!id))
  );
  if (uniq.length === 0) return new Map();
  const { data } = await supabase
    .from('profiles')
    .select('id, display_name, email')
    .in('id', uniq);
  return new Map(
    (data ?? []).map((p) => [
      p.id as string,
      {
        id: p.id as string,
        display_name: (p.display_name as string) ?? '',
        email: (p.email as string) ?? ''
      }
    ])
  );
}
