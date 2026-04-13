import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent, params, url }) => {
  const { currentTenant } = await parent();
  const page = Math.max(1, parseInt(url.searchParams.get('page') ?? '1'));
  const perPage = 20;

  // Board info
  const { data: board, error: bErr } = await locals.supabase
    .from('boards')
    .select('id, name, description, board_type')
    .eq('id', params.boardId)
    .eq('tenant_id', currentTenant.id)
    .single();

  if (bErr || !board) error(404, '게시판을 찾을 수 없습니다');

  // Posts with pagination
  const { data: posts, count } = await locals.supabase
    .from('board_posts')
    .select('id, title, author_id, is_pinned, view_count, created_at', { count: 'exact' })
    .eq('board_id', params.boardId)
    .order('is_pinned', { ascending: false })
    .order('created_at', { ascending: false })
    .range((page - 1) * perPage, page * perPage - 1);

  // Comment counts
  const postIds = (posts ?? []).map((p) => p.id as string);
  let commentCounts = new Map<string, number>();
  if (postIds.length > 0) {
    const { data: comments } = await locals.supabase
      .from('board_comments')
      .select('post_id')
      .in('post_id', postIds);
    if (comments) {
      for (const c of comments) {
        const pid = c.post_id as string;
        commentCounts.set(pid, (commentCounts.get(pid) ?? 0) + 1);
      }
    }
  }

  // Author profiles
  const authorIds = (posts ?? []).map((p) => p.author_id as string);
  const profiles = await fetchProfilesByIds(locals.supabase, authorIds);

  return {
    board: {
      id: board.id as string,
      name: board.name as string,
      description: (board.description as string | null) ?? null,
      board_type: board.board_type as string
    },
    posts: (posts ?? []).map((p) => ({
      id: p.id as string,
      title: p.title as string,
      author_name: profiles.get(p.author_id as string)?.display_name ?? '(알 수 없음)',
      is_pinned: p.is_pinned as boolean,
      view_count: p.view_count as number,
      comment_count: commentCounts.get(p.id as string) ?? 0,
      created_at: p.created_at as string
    })),
    page,
    totalPages: Math.ceil((count ?? 0) / perPage)
  };
};
