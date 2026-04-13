import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();

  const { data: boards } = await locals.supabase
    .from('boards')
    .select('id, name, description, board_type, department_id, is_active, sort_order, created_at')
    .eq('tenant_id', currentTenant.id)
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  // Get post counts per board
  const boardIds = (boards ?? []).map((b) => b.id as string);
  let postCounts = new Map<string, number>();
  if (boardIds.length > 0) {
    const { data: counts } = await locals.supabase
      .from('board_posts')
      .select('board_id', { count: 'exact', head: false })
      .in('board_id', boardIds);

    // Count per board_id
    if (counts) {
      for (const row of counts) {
        const bid = row.board_id as string;
        postCounts.set(bid, (postCounts.get(bid) ?? 0) + 1);
      }
    }
  }

  return {
    boards: (boards ?? []).map((b) => ({
      id: b.id as string,
      name: b.name as string,
      description: (b.description as string | null) ?? null,
      board_type: b.board_type as string,
      post_count: postCounts.get(b.id as string) ?? 0
    }))
  };
};
