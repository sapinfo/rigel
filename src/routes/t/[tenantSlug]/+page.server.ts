import type { PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();
	const userId = locals.user!.id;
	const tenantId = currentTenant.id;

	// 1. 6카드 count — status별 GROUP BY 대신 개별 count (RLS 호환)
	const [pending, inProgress, completed, rejected, drafts] = await Promise.all([
		// pending: 내가 현재 결재자인 문서
		(async () => {
			const { data: steps } = await locals.supabase
				.from('approval_steps')
				.select('document_id, step_index')
				.eq('tenant_id', tenantId)
				.eq('approver_user_id', userId)
				.eq('status', 'pending');

			if (!steps || steps.length === 0) return 0;

			const { data: docs } = await locals.supabase
				.from('approval_documents')
				.select('id, current_step_index')
				.in('id', steps.map((s) => s.document_id as string))
				.in('status', ['in_progress', 'pending_post_facto']);

			const stepMap = new Map(steps.map((s) => [s.document_id as string, s.step_index as number]));
			return (docs ?? []).filter((d) => stepMap.get(d.id as string) === (d.current_step_index as number)).length;
		})(),
		locals.supabase.from('approval_documents').select('id', { count: 'exact', head: true })
			.eq('tenant_id', tenantId).eq('drafter_id', userId).in('status', ['in_progress', 'pending_post_facto']),
		locals.supabase.from('approval_documents').select('id', { count: 'exact', head: true })
			.eq('tenant_id', tenantId).eq('drafter_id', userId).in('status', ['completed', 'withdrawn']),
		locals.supabase.from('approval_documents').select('id', { count: 'exact', head: true })
			.eq('tenant_id', tenantId).eq('drafter_id', userId).eq('status', 'rejected'),
		locals.supabase.from('approval_documents').select('id', { count: 'exact', head: true })
			.eq('tenant_id', tenantId).eq('drafter_id', userId).eq('status', 'draft')
	]);

	// 2. 즐겨찾기 (상위 5개)
	const { data: favRows } = await locals.supabase
		.from('approval_line_favorites')
		.select('id, name')
		.eq('tenant_id', tenantId)
		.eq('user_id', userId)
		.order('created_at', { ascending: false })
		.limit(5);

	// 3. 부재 현황
	const { data: absentRows } = await locals.supabase
		.from('user_absences')
		.select('user_id, proxy_user_id')
		.eq('tenant_id', tenantId)
		.eq('is_active', true);

	const absentUserIds = (absentRows ?? []).flatMap((r) => [r.user_id as string, r.proxy_user_id as string | null].filter(Boolean)) as string[];
	const absentProfiles = await fetchProfilesByIds(locals.supabase, absentUserIds);

	const absentMembers = (absentRows ?? []).map((r) => {
		const user = absentProfiles.get(r.user_id as string);
		const proxy = r.proxy_user_id ? absentProfiles.get(r.proxy_user_id as string) : null;
		return {
			name: user?.display_name ?? '(알 수 없음)',
			proxyName: proxy?.display_name ?? '미지정'
		};
	});

	// 4. 긴급 미결 count
	const { count: urgentCount } = await locals.supabase
		.from('approval_documents')
		.select('id', { count: 'exact', head: true })
		.eq('tenant_id', tenantId)
		.eq('urgency', '긴급')
		.in('status', ['in_progress', 'pending_post_facto']);

	// 5. 현재 사용자 이름
	const profileMap = await fetchProfilesByIds(locals.supabase, [userId]);
	const userName = profileMap.get(userId)?.display_name ?? '사용자';

	// 6. 최근 기안문서 (10건)
	const { data: recentDocs } = await locals.supabase
		.from('approval_documents')
		.select('id, doc_number, status, form_id, submitted_at, updated_at, urgency, content')
		.eq('tenant_id', tenantId)
		.eq('drafter_id', userId)
		.order('updated_at', { ascending: false })
		.limit(10);

	const recentFormIds = (recentDocs ?? []).map((d) => d.form_id as string);
	const { data: recentFormRows } = recentFormIds.length
		? await locals.supabase.from('approval_forms').select('id, name').in('id', [...new Set(recentFormIds)])
		: { data: [] };
	const recentFormMap = new Map((recentFormRows ?? []).map((f) => [f.id as string, f.name as string]));

	const recentDocuments = (recentDocs ?? []).map((d) => ({
		id: d.id as string,
		docNumber: d.doc_number as string,
		status: d.status as string,
		formName: recentFormMap.get(d.form_id as string) ?? '(양식 없음)',
		title: ((d.content as Record<string, unknown>)?.title as string) ?? '',
		submittedAt: (d.submitted_at as string | null) ?? null,
		updatedAt: d.updated_at as string,
		urgency: (d.urgency as string) ?? '일반'
	}));

	// 7. 양식 목록 (빠른 기안용)
	const { data: formRows } = await locals.supabase
		.from('approval_forms')
		.select('code, name')
		.eq('tenant_id', tenantId)
		.eq('is_published', true)
		.order('name');

	// ─── v3.1 Dashboard widgets ───────────────────────
	const today = new Date().toLocaleDateString('sv-SE'); // YYYY-MM-DD
	const monthStart = today.slice(0, 8) + '01';
	const monthEnd = new Date(new Date(today).getFullYear(), new Date(today).getMonth() + 1, 0).toISOString().slice(0, 10);

	const [
		unreadAnnouncementRes,
		todayAttendanceRes,
		todayEventsRes,
		recentPostsRes
	] = await Promise.all([
		// 미확인 공지 수
		locals.supabase.rpc('get_unread_announcement_count', { p_tenant_id: tenantId }),
		// 오늘 출근 기록
		locals.supabase
			.from('attendance_records')
			.select('clock_in, clock_out, work_type')
			.eq('tenant_id', tenantId)
			.eq('user_id', userId)
			.eq('work_date', today)
			.maybeSingle(),
		// 오늘 일정
		locals.supabase
			.from('calendar_events')
			.select('id, title, start_at, end_at, all_day, event_type')
			.eq('tenant_id', tenantId)
			.lte('start_at', today + 'T23:59:59+09:00')
			.gte('end_at', today + 'T00:00:00+09:00')
			.order('start_at')
			.limit(5),
		// 최근 게시글
		locals.supabase
			.from('board_posts')
			.select('id, title, board_id, created_at, boards!inner(name)')
			.eq('tenant_id', tenantId)
			.order('created_at', { ascending: false })
			.limit(5)
	]);

	return {
		userName,
		counts: {
			pending: typeof pending === 'number' ? pending : 0,
			inProgress: inProgress.count ?? 0,
			completed: completed.count ?? 0,
			rejected: rejected.count ?? 0,
			drafts: drafts.count ?? 0
		},
		urgentCount: urgentCount ?? 0,
		favorites: (favRows ?? []).map((f) => ({ id: f.id as string, name: f.name as string })),
		absentMembers,
		recentDocuments,
		forms: (formRows ?? []).map((f) => ({ code: f.code as string, name: f.name as string })),
		// v3.1 widgets
		unreadAnnouncementCount: (unreadAnnouncementRes.data as number) ?? 0,
		todayAttendance: todayAttendanceRes.data ?? null,
		todayEvents: (todayEventsRes.data ?? []).map((e) => ({
			id: e.id as string,
			title: e.title as string,
			startAt: e.start_at as string,
			allDay: e.all_day as boolean,
			eventType: e.event_type as string
		})),
		recentPosts: (recentPostsRes.data ?? []).map((p) => ({
			id: p.id as string,
			title: p.title as string,
			boardId: p.board_id as string,
			boardName: (p.boards as unknown as { name: string } | null)?.name ?? '',
			createdAt: p.created_at as string
		}))
	};
};
