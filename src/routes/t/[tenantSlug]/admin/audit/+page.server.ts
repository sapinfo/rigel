import type { PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent, url }) => {
	const { currentTenant } = await parent();
	const page = parseInt(url.searchParams.get('page') ?? '1', 10);
	const perPage = 50;
	const offset = (page - 1) * perPage;

	const { data: logs, count } = await locals.supabase
		.from('approval_audit_logs')
		.select('id, actor_id, action, payload, created_at, document_id', { count: 'exact' })
		.eq('tenant_id', currentTenant.id)
		.order('created_at', { ascending: false })
		.range(offset, offset + perPage - 1);

	const actorIds = (logs ?? []).map((l) => l.actor_id as string);
	const profileMap = await fetchProfilesByIds(locals.supabase, actorIds);

	const rows = (logs ?? []).map((l) => ({
		id: l.id as string,
		actorName: profileMap.get(l.actor_id as string)?.display_name ?? '(알 수 없음)',
		actorEmail: profileMap.get(l.actor_id as string)?.email ?? '',
		action: l.action as string,
		documentId: (l.document_id as string | null) ?? null,
		payload: l.payload as Record<string, unknown>,
		createdAt: l.created_at as string
	}));

	return {
		rows,
		totalCount: count ?? 0,
		currentPage: page,
		perPage
	};
};
