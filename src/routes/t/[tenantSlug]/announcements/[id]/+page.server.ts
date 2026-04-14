import { error, fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { currentTenant } = await parent();

  const { data: ann, error: aErr } = await locals.supabase
    .from('announcements')
    .select('*')
    .eq('id', params.id)
    .eq('tenant_id', currentTenant.id)
    .single();

  if (aErr || !ann) error(404, '공지를 찾을 수 없습니다');

  const profiles = await fetchProfilesByIds(locals.supabase, [ann.author_id as string]);

  // Check if already read
  let isRead = false;
  if (locals.user) {
    const { data: readRow } = await locals.supabase
      .from('announcement_reads')
      .select('read_at')
      .eq('announcement_id', params.id)
      .eq('user_id', locals.user.id)
      .maybeSingle();
    isRead = !!readRow;
  }

  return {
    announcement: {
      id: ann.id as string,
      title: ann.title as string,
      content: ann.content as Record<string, unknown>,
      author_name: profiles.get(ann.author_id as string)?.display_name ?? '',
      is_popup: ann.is_popup as boolean,
      require_read_confirm: ann.require_read_confirm as boolean,
      published_at: ann.published_at as string,
      expires_at: (ann.expires_at as string | null) ?? null,
      is_read: isRead
    }
  };
};

export const actions: Actions = {
  markRead: async ({ locals, params }) => {
    if (!locals.user) return fail(401);

    const { data: tm } = await locals.supabase
      .from('tenant_members')
      .select('tenant:tenants!inner(id)')
      .eq('user_id', locals.user.id)
      .eq('tenant.slug', params.tenantSlug)
      .maybeSingle();
    if (!tm) return fail(403);
    const tenantId = (tm.tenant as unknown as { id: string }).id;

    // upsert의 UPDATE 경로는 RLS UPDATE 정책이 필요한데 현재 없음.
    // ignoreDuplicates=true로 conflict 시 아무것도 안 하게 하여
    // INSERT 권한만으로 동작. 이미 읽음이면 no-op.
    const { error: insErr } = await locals.supabase
      .from('announcement_reads')
      .upsert(
        {
          announcement_id: params.id,
          user_id: locals.user.id,
          tenant_id: tenantId,
          read_at: new Date().toISOString()
        },
        { onConflict: 'announcement_id,user_id', ignoreDuplicates: true }
      );

    if (insErr) return fail(500, { message: insErr.message });
    return { ok: true };
  }
};
