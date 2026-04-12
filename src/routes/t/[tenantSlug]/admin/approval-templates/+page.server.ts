import { error, fail } from '@sveltejs/kit';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { ApprovalLineItem } from '$lib/types/approval';

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
	const t = data.tenant as unknown as { id: string };
	if (!['owner', 'admin'].includes(data.role as string)) return null;
	return { id: t.id };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();
	if (!currentTenant) error(404);

	const { data: templates } = await locals.supabase
		.from('approval_line_templates')
		.select('id, name, form_id, line_json, is_default, priority, created_at')
		.eq('tenant_id', currentTenant.id)
		.order('priority', { ascending: true });

	const { data: forms } = await locals.supabase
		.from('approval_forms')
		.select('id, name, code')
		.eq('tenant_id', currentTenant.id)
		.eq('is_published', true);

	// 멤버 (line_json 표시용)
	const { data: memberRows } = await locals.supabase
		.from('tenant_members')
		.select('user_id, job_title')
		.eq('tenant_id', currentTenant.id);

	const profileMap = await fetchProfilesByIds(
		locals.supabase,
		(memberRows ?? []).map((r) => r.user_id as string)
	);

	const members = (memberRows ?? []).map((r) => {
		const p = profileMap.get(r.user_id as string);
		return {
			id: r.user_id as string,
			displayName: p?.display_name ?? '(알 수 없음)',
			jobTitle: (r.job_title as string | null) ?? null
		};
	});

	return {
		templates: (templates ?? []).map((t) => ({
			id: t.id as string,
			name: t.name as string,
			formId: (t.form_id as string | null) ?? null,
			lineJson: t.line_json as unknown as ApprovalLineItem[],
			isDefault: t.is_default as boolean,
			priority: t.priority as number
		})),
		availableForms: (forms ?? []).map((f) => ({
			id: f.id as string,
			name: f.name as string,
			code: f.code as string
		})),
		members
	};
};

export const actions: Actions = {
	create: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const name = fd.get('name')?.toString()?.trim();
		const formId = fd.get('formId')?.toString() || null;
		const lineJsonRaw = fd.get('lineJson')?.toString();
		const priority = parseInt(fd.get('priority')?.toString() ?? '100', 10);
		const isDefault = fd.get('isDefault')?.toString() === 'true';

		if (!name || !lineJsonRaw) return fail(400, { actionError: '이름과 결재선이 필요합니다' });

		let lineJson;
		try { lineJson = JSON.parse(lineJsonRaw); } catch { return fail(400, { actionError: '잘못된 결재선 데이터' }); }

		const { error: err } = await locals.supabase
			.from('approval_line_templates')
			.insert({
				tenant_id: tenant.id,
				name,
				form_id: formId,
				line_json: lineJson,
				is_default: isDefault,
				priority,
				created_by: locals.user.id
			});

		if (err) return fail(500, { actionError: err.message });
		return { ok: true };
	},

	update: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const name = fd.get('name')?.toString()?.trim();
		const formId = fd.get('formId')?.toString() || null;
		const lineJsonRaw = fd.get('lineJson')?.toString();
		const priority = parseInt(fd.get('priority')?.toString() ?? '100', 10);
		const isDefault = fd.get('isDefault')?.toString() === 'true';

		if (!id || !name || !lineJsonRaw) return fail(400, { actionError: '필수 값 누락' });

		let lineJson;
		try { lineJson = JSON.parse(lineJsonRaw); } catch { return fail(400, { actionError: '잘못된 결재선 데이터' }); }

		const { error: err } = await locals.supabase
			.from('approval_line_templates')
			.update({ name, form_id: formId, line_json: lineJson, is_default: isDefault, priority })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		if (err) return fail(500, { actionError: err.message });
		return { ok: true };
	},

	delete: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		if (!id) return fail(400);

		await locals.supabase
			.from('approval_line_templates')
			.delete()
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		return { ok: true };
	},

	setDefault: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		if (!id) return fail(400);

		// 기존 default 해제
		await locals.supabase
			.from('approval_line_templates')
			.update({ is_default: false })
			.eq('tenant_id', tenant.id)
			.eq('is_default', true);

		// 새 default 설정
		await locals.supabase
			.from('approval_line_templates')
			.update({ is_default: true })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		return { ok: true };
	}
};
