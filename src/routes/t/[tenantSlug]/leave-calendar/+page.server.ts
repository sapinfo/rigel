import type { PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

export const load: PageServerLoad = async ({ locals, parent, url }) => {
	const { currentTenant } = await parent();
	const tenantId = currentTenant.id;

	// 월 파라미터 (YYYY-MM)
	const now = new Date();
	const monthParam = url.searchParams.get('month');
	const [year, month] = monthParam
		? monthParam.split('-').map(Number)
		: [now.getFullYear(), now.getMonth() + 1];

	const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
	const endMonth = month === 12 ? 1 : month + 1;
	const endYear = month === 12 ? year + 1 : year;
	const endDate = `${endYear}-${String(endMonth).padStart(2, '0')}-01`;

	// 부서 목록 (필터용)
	const { data: depts } = await locals.supabase
		.from('departments')
		.select('id, name')
		.eq('tenant_id', tenantId)
		.order('name');

	const deptFilter = url.searchParams.get('dept') ?? '';

	// 휴가신청서 form_id 조회
	const { data: leaveForms } = await locals.supabase
		.from('approval_forms')
		.select('id')
		.eq('code', 'leave-request')
		.or(`tenant_id.eq.${tenantId},tenant_id.is.null`);

	const leaveFormIds = (leaveForms ?? []).map((f) => f.id as string);
	if (leaveFormIds.length === 0) {
		return { year, month, days: 31, leaves: [], departments: depts ?? [], deptFilter };
	}

	// 승인된 휴가 문서 조회
	const { data: docs } = await locals.supabase
		.from('approval_documents')
		.select('id, drafter_id, content, status, form_id')
		.eq('tenant_id', tenantId)
		.in('form_id', leaveFormIds)
		.eq('status', 'completed');

	// 기안자 프로필 + 부서
	const drafterIds = (docs ?? []).map((d) => d.drafter_id as string);
	const profileMap = await fetchProfilesByIds(locals.supabase, drafterIds);

	const { data: memberRows } = await locals.supabase
		.from('tenant_members')
		.select('user_id, department_id')
		.eq('tenant_id', tenantId)
		.in('user_id', drafterIds.length > 0 ? drafterIds : ['__none__']);

	const memberDeptMap = new Map((memberRows ?? []).map((r) => [r.user_id as string, r.department_id as string | null]));
	const deptNameMap = new Map((depts ?? []).map((d) => [d.id as string, d.name as string]));

	// 휴가 데이터 파싱
	type LeaveEntry = {
		id: string;
		drafterName: string;
		departmentName: string;
		departmentId: string | null;
		leaveType: string;
		startDate: string;
		endDate: string;
		status: string;
	};

	const leaveTypeLabels: Record<string, string> = {
		annual: '연차', half: '반차', sick: '병가', family: '경조사', unpaid: '무급'
	};

	const leaves: LeaveEntry[] = [];

	for (const doc of docs ?? []) {
		const content = doc.content as Record<string, unknown>;
		const period = content.period as { start?: string; end?: string } | undefined;
		if (!period?.start || !period?.end) continue;

		// 이 달과 겹치는지 확인
		if (period.end < startDate || period.start >= endDate) continue;

		const drafterId = doc.drafter_id as string;
		const deptId = memberDeptMap.get(drafterId) ?? null;

		// 부서 필터
		if (deptFilter && deptId !== deptFilter) continue;

		const p = profileMap.get(drafterId);
		leaves.push({
			id: doc.id as string,
			drafterName: p?.display_name ?? '(알 수 없음)',
			departmentName: deptId ? (deptNameMap.get(deptId) ?? '') : '',
			departmentId: deptId,
			leaveType: leaveTypeLabels[(content.leave_type as string) ?? ''] ?? (content.leave_type as string) ?? '',
			startDate: period.start,
			endDate: period.end,
			status: doc.status as string
		});
	}

	// 이 달의 일수
	const daysInMonth = new Date(year, month, 0).getDate();
	const firstDayOfWeek = new Date(year, month - 1, 1).getDay(); // 0=Sun

	return {
		year,
		month,
		daysInMonth,
		firstDayOfWeek,
		leaves,
		departments: (depts ?? []).map((d) => ({ id: d.id as string, name: d.name as string })),
		deptFilter
	};
};
