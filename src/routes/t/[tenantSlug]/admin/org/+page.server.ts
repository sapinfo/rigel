import { fail } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';

async function resolveTenantAdmin(
	supabase: SupabaseClient,
	userId: string,
	slug: string
): Promise<{ id: string } | null> {
	const { data } = await supabase
		.from('tenant_members')
		.select('role, tenant:tenants!inner(id, slug)')
		.eq('user_id', userId)
		.eq('tenant.slug', slug)
		.maybeSingle();
	if (!data) return null;
	const t = data.tenant as unknown as { id: string; slug: string };
	if (!['owner', 'admin'].includes(data.role as string)) return null;
	return { id: t.id };
}

// ─── Schemas ─────────────────────────────────────
const deptSchema = z.object({ name: z.string().trim().min(1).max(100) });
const jobTitleSchema = z.object({
	name: z.string().trim().min(1).max(100),
	level: z.coerce.number().int().min(1).max(10)
});

// ─── Load ────────────────────────────────────────
export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();

	// 1. 부서 (트리 빌드용)
	const { data: depts } = await locals.supabase
		.from('departments')
		.select('id, name, path, parent_id, sort_order')
		.eq('tenant_id', currentTenant.id)
		.order('sort_order', { ascending: true })
		.order('name', { ascending: true });

	// 2. 직급
	const { data: jobTitles } = await locals.supabase
		.from('job_titles')
		.select('id, name, level')
		.eq('tenant_id', currentTenant.id)
		.order('level', { ascending: true });

	// 3. 멤버 (부서·직급 할당 현황)
	const { data: memberRows } = await locals.supabase
		.from('tenant_members')
		.select('user_id, department_id, job_title_id, role')
		.eq('tenant_id', currentTenant.id);

	// 4. 프로필 (2-query join)
	const userIds = (memberRows ?? []).map((r) => r.user_id as string);
	const profileMap = await fetchProfilesByIds(locals.supabase, userIds);

	const members = (memberRows ?? []).map((r) => {
		const p = profileMap.get(r.user_id as string);
		return {
			userId: r.user_id as string,
			displayName: p?.display_name ?? '(알 수 없음)',
			email: p?.email ?? '',
			departmentId: (r.department_id as string | null) ?? null,
			jobTitleId: (r.job_title_id as string | null) ?? null,
			role: r.role as string
		};
	});

	return {
		departments: (depts ?? []).map((d) => ({
			id: d.id as string,
			name: d.name as string,
			path: d.path as string,
			parentId: (d.parent_id as string | null) ?? null,
			sortOrder: (d.sort_order as number) ?? 0
		})),
		jobTitles: (jobTitles ?? []).map((j) => ({
			id: j.id as string,
			name: j.name as string,
			level: j.level as number
		})),
		members
	};
};

// ─── Cycle check for reparent ────────────────────
async function wouldCycle(
	supabase: SupabaseClient,
	tenantId: string,
	deptId: string,
	newParentId: string
): Promise<boolean> {
	if (deptId === newParentId) return true;
	let current: string | null = newParentId;
	const visited = new Set<string>();
	while (current) {
		if (current === deptId) return true;
		if (visited.has(current)) return true;
		visited.add(current);
		const { data: row }: { data: { parent_id: string | null } | null } = await supabase
			.from('departments')
			.select('parent_id')
			.eq('id', current)
			.eq('tenant_id', tenantId)
			.maybeSingle();
		current = row?.parent_id ?? null;
	}
	return false;
}

// ─── Actions ─────────────────────────────────────
export const actions: Actions = {
	// ── 부서 CRUD ──────────────────────────────────
	createDept: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const parsed = deptSchema.safeParse({ name: fd.get('name') });
		if (!parsed.success) return fail(400, { errors: zodErrors(parsed) });

		const parentId = fd.get('parentId')?.toString() || null;
		const { name } = parsed.data;
		const path = `/${name.toLowerCase().replace(/\s+/g, '-')}`;

		const { error: err } = await locals.supabase.from('departments').insert({
			tenant_id: tenant.id,
			name,
			path,
			parent_id: parentId,
			sort_order: 0
		});

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	updateDept: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const parsed = deptSchema.safeParse({ name: fd.get('name') });
		if (!id || !parsed.success) return fail(400);

		const path = `/${parsed.data.name.toLowerCase().replace(/\s+/g, '-')}`;
		const { error: err } = await locals.supabase
			.from('departments')
			.update({ name: parsed.data.name, path })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	reparent: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const newParentId = fd.get('newParentId')?.toString() || null;
		if (!id) return fail(400);

		if (newParentId) {
			const cycle = await wouldCycle(locals.supabase, tenant.id, id, newParentId);
			if (cycle) return fail(400, { errors: formError('순환 참조가 발생합니다.') });
		}

		const { error: err } = await locals.supabase
			.from('departments')
			.update({ parent_id: newParentId })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	removeDept: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		if (!id) return fail(400);

		// 하위 부서 존재 확인
		const { data: children } = await locals.supabase
			.from('departments')
			.select('id')
			.eq('parent_id', id)
			.eq('tenant_id', tenant.id)
			.limit(1);

		if (children && children.length > 0) {
			return fail(400, { errors: formError('하위 부서가 있어 삭제할 수 없습니다. 먼저 하위 부서를 이동하거나 삭제하세요.') });
		}

		const { error: err } = await locals.supabase
			.from('departments')
			.delete()
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	// ── 직급 CRUD ──────────────────────────────────
	createJobTitle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const parsed = jobTitleSchema.safeParse({
			name: fd.get('name'),
			level: fd.get('level')
		});
		if (!parsed.success) return fail(400, { errors: zodErrors(parsed) });

		const { error: err } = await locals.supabase.from('job_titles').insert({
			tenant_id: tenant.id,
			name: parsed.data.name,
			level: parsed.data.level
		});

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	updateJobTitle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const parsed = jobTitleSchema.safeParse({
			name: fd.get('name'),
			level: fd.get('level')
		});
		if (!id) return fail(400);
		if (!parsed.success) return fail(400, { errors: zodErrors(parsed) });

		const { error: err } = await locals.supabase
			.from('job_titles')
			.update({ name: parsed.data.name, level: parsed.data.level })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	removeJobTitle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		if (!id) return fail(400);

		const { error: err } = await locals.supabase
			.from('job_titles')
			.delete()
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	// ── 멤버 할당 ──────────────────────────────────
	assignDept: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const userId = fd.get('userId')?.toString();
		const deptId = fd.get('departmentId')?.toString() || null;
		if (!userId) return fail(400);

		const { error: err } = await locals.supabase
			.from('tenant_members')
			.update({ department_id: deptId })
			.eq('user_id', userId)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	},

	assignJobTitle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const userId = fd.get('userId')?.toString();
		const jobTitleId = fd.get('jobTitleId')?.toString() || null;
		if (!userId) return fail(400);

		const { error: err } = await locals.supabase
			.from('tenant_members')
			.update({ job_title_id: jobTitleId })
			.eq('user_id', userId)
			.eq('tenant_id', tenant.id);

		if (err) return fail(400, { errors: formError(err.message) });
		return { ok: true };
	}
};
