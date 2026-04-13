import type { PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();

  const { data: announcements } = await locals.supabase
    .from('announcements')
    .select('id, title, author_id, is_popup, require_read_confirm, published_at, expires_at, created_at')
    .eq('tenant_id', currentTenant.id)
    .not('published_at', 'is', null)
    .order('published_at', { ascending: false });

  // Check which ones user has read
  const announcementIds = (announcements ?? []).map((a) => a.id as string);
  let readSet = new Set<string>();
  if (announcementIds.length > 0 && locals.user) {
    const { data: reads } = await locals.supabase
      .from('announcement_reads')
      .select('announcement_id')
      .eq('user_id', locals.user.id)
      .in('announcement_id', announcementIds);
    if (reads) {
      readSet = new Set(reads.map((r) => r.announcement_id as string));
    }
  }

  const authorIds = (announcements ?? []).map((a) => a.author_id as string);
  const profiles = await fetchProfilesByIds(locals.supabase, authorIds);

  return {
    announcements: (announcements ?? []).map((a) => ({
      id: a.id as string,
      title: a.title as string,
      author_name: profiles.get(a.author_id as string)?.display_name ?? '',
      is_popup: a.is_popup as boolean,
      require_read_confirm: a.require_read_confirm as boolean,
      is_read: readSet.has(a.id as string),
      published_at: a.published_at as string
    }))
  };
};
