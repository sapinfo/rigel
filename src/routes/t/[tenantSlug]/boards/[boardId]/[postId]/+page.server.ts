import { error, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { SupabaseClient } from '@supabase/supabase-js';

async function resolveTenant(
  supabase: SupabaseClient,
  userId: string,
  slug: string
): Promise<{ id: string; role: string } | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  const t = data.tenant as unknown as { id: string; slug: string };
  return { id: t.id, role: data.role as string };
}

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { currentTenant } = await parent();

  // Post detail
  const { data: post, error: pErr } = await locals.supabase
    .from('board_posts')
    .select('id, board_id, title, content, author_id, is_pinned, view_count, created_at, updated_at')
    .eq('id', params.postId)
    .eq('board_id', params.boardId)
    .single();

  if (pErr || !post) error(404, '게시글을 찾을 수 없습니다');

  // Increment view count (fire-and-forget)
  locals.supabase.rpc('increment_post_view', { p_post_id: params.postId });

  // Comments
  const { data: comments } = await locals.supabase
    .from('board_comments')
    .select('id, post_id, author_id, content, created_at')
    .eq('post_id', params.postId)
    .order('created_at', { ascending: true });

  // Profiles
  const allIds = [
    post.author_id as string,
    ...(comments ?? []).map((c) => c.author_id as string)
  ];
  const profiles = await fetchProfilesByIds(locals.supabase, allIds);

  const isAdmin = currentTenant.role === 'owner' || currentTenant.role === 'admin';
  const isAuthor = post.author_id === locals.user?.id;

  return {
    post: {
      id: post.id as string,
      board_id: post.board_id as string,
      title: post.title as string,
      content: post.content as Record<string, unknown>,
      author_id: post.author_id as string,
      author_name: profiles.get(post.author_id as string)?.display_name ?? '(알 수 없음)',
      is_pinned: post.is_pinned as boolean,
      view_count: (post.view_count as number) + 1,
      created_at: post.created_at as string
    },
    comments: (comments ?? []).map((c) => ({
      id: c.id as string,
      author_id: c.author_id as string,
      author_name: profiles.get(c.author_id as string)?.display_name ?? '(알 수 없음)',
      content: c.content as string,
      created_at: c.created_at as string
    })),
    canEdit: isAuthor || isAdmin,
    isAdmin,
    currentUserId: locals.user!.id
  };
};

export const actions: Actions = {
  comment: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(403);

    const fd = await request.formData();
    const content = fd.get('content')?.toString()?.trim();
    if (!content) return fail(400, { error: '댓글을 입력하세요' });

    const { error: err } = await locals.supabase
      .from('board_comments')
      .insert({
        post_id: params.postId,
        tenant_id: tenant.id,
        author_id: locals.user.id,
        content
      });
    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  deleteComment: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const fd = await request.formData();
    const commentId = fd.get('commentId')?.toString();
    if (!commentId) return fail(400);

    const { error: err } = await locals.supabase
      .from('board_comments')
      .delete()
      .eq('id', commentId);
    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  deletePost: async ({ locals, params }) => {
    if (!locals.user) return fail(401);

    const { error: err } = await locals.supabase
      .from('board_posts')
      .delete()
      .eq('id', params.postId);
    if (err) return fail(400, { error: err.message });

    redirect(303, `/t/${params.tenantSlug}/boards/${params.boardId}`);
  },

  togglePin: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const pin = fd.get('pin') === 'true';

    const { error: err } = await locals.supabase
      .from('board_posts')
      .update({ is_pinned: pin })
      .eq('id', params.postId);
    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
