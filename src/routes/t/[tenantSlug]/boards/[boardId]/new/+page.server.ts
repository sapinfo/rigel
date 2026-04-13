import { error, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { currentTenant } = await parent();

  const { data: board, error: bErr } = await locals.supabase
    .from('boards')
    .select('id, name')
    .eq('id', params.boardId)
    .eq('tenant_id', currentTenant.id)
    .single();

  if (bErr || !board) error(404, '게시판을 찾을 수 없습니다');

  return {
    board: { id: board.id as string, name: board.name as string }
  };
};

export const actions: Actions = {
  default: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);

    const fd = await request.formData();
    const title = fd.get('title')?.toString()?.trim();
    const content = fd.get('content')?.toString() ?? '';

    if (!title) return fail(400, { error: '제목을 입력하세요' });

    // Resolve tenant
    const { data: tm } = await locals.supabase
      .from('tenant_members')
      .select('tenant:tenants!inner(id, slug)')
      .eq('user_id', locals.user.id)
      .eq('tenant.slug', params.tenantSlug)
      .maybeSingle();
    if (!tm) return fail(403);
    const tenantId = (tm.tenant as unknown as { id: string }).id;

    const { error: insErr } = await locals.supabase
      .from('board_posts')
      .insert({
        board_id: params.boardId,
        tenant_id: tenantId,
        title,
        content: content ? JSON.parse(content) : {},
        author_id: locals.user.id
      });

    if (insErr) return fail(400, { error: insErr.message });

    redirect(303, `/t/${params.tenantSlug}/boards/${params.boardId}`);
  }
};
