import { error, fail } from '@sveltejs/kit';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { FormSchema } from '$lib/types/approval';

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

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();
	if (!currentTenant) error(404);

	// 규칙 목록
	const { data: rules } = await locals.supabase
		.from('approval_rules')
		.select('id, name, form_id, condition_json, line_template_json, priority, is_active, created_at')
		.eq('tenant_id', currentTenant.id)
		.order('priority', { ascending: true });

	// 양식 목록 (schema 포함 — 필드 드롭다운용)
	const { data: forms } = await locals.supabase
		.from('approval_forms')
		.select('id, name, code, schema')
		.eq('tenant_id', currentTenant.id)
		.eq('is_published', true);

	const availableForms = (forms ?? []).map((f) => {
		const schema = f.schema as unknown as FormSchema | null;
		return {
			id: f.id as string,
			name: f.name as string,
			code: f.code as string,
			fields: (schema?.fields ?? []).map((field) => ({ id: field.id, label: field.label }))
		};
	});

	// 멤버 (직접 지정용)
	const { data: memberRows } = await locals.supabase
		.from('tenant_members')
		.select('user_id, job_title_id')
		.eq('tenant_id', currentTenant.id);

	const userIds = (memberRows ?? []).map((r) => r.user_id as string);
	const profileMap = await fetchProfilesByIds(locals.supabase, userIds);

	const { data: jtRows } = await locals.supabase
		.from('job_titles')
		.select('id, name')
		.eq('tenant_id', currentTenant.id);
	const jtMap = new Map((jtRows ?? []).map((j) => [j.id as string, j.name as string]));

	const members = (memberRows ?? []).map((r) => {
		const p = profileMap.get(r.user_id as string);
		return {
			id: r.user_id as string,
			displayName: p?.display_name ?? '(알 수 없음)',
			jobTitle: r.job_title_id ? (jtMap.get(r.job_title_id as string) ?? null) : null
		};
	});

	return {
		rules: (rules ?? []).map((r) => ({
			id: r.id as string,
			name: r.name as string,
			formId: (r.form_id as string | null) ?? null,
			conditionJson: r.condition_json as Record<string, unknown> | null,
			lineTemplateJson: r.line_template_json as unknown[],
			priority: r.priority as number,
			isActive: r.is_active as boolean
		})),
		availableForms,
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
		const priority = parseInt(fd.get('priority')?.toString() ?? '100', 10);
		const conditionJsonRaw = fd.get('conditionJson')?.toString() || null;
		const lineTemplateRaw = fd.get('lineTemplateJson')?.toString();

		if (!name) return fail(400, { actionError: '규칙 이름 필수' });
		if (!lineTemplateRaw) return fail(400, { actionError: '결재선 구성 필수' });

		let lineTemplate;
		try {
			lineTemplate = JSON.parse(lineTemplateRaw);
		} catch {
			return fail(400, { actionError: '잘못된 결재선 데이터' });
		}

		let conditionJson = null;
		if (conditionJsonRaw) {
			try {
				conditionJson = JSON.parse(conditionJsonRaw);
			} catch {
				return fail(400, { actionError: '잘못된 조건 데이터' });
			}
		}

		const { error: err } = await locals.supabase
			.from('approval_rules')
			.insert({
				tenant_id: tenant.id,
				name,
				form_id: formId,
				condition_json: conditionJson,
				line_template_json: lineTemplate,
				priority,
				is_active: true
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
		const priority = parseInt(fd.get('priority')?.toString() ?? '100', 10);
		const conditionJsonRaw = fd.get('conditionJson')?.toString() || null;
		const lineTemplateRaw = fd.get('lineTemplateJson')?.toString();

		if (!id || !name) return fail(400, { actionError: '필수 값 누락' });
		if (!lineTemplateRaw) return fail(400, { actionError: '결재선 구성 필수' });

		let lineTemplate;
		try {
			lineTemplate = JSON.parse(lineTemplateRaw);
		} catch {
			return fail(400, { actionError: '잘못된 결재선 데이터' });
		}

		let conditionJson = null;
		if (conditionJsonRaw) {
			try {
				conditionJson = JSON.parse(conditionJsonRaw);
			} catch {
				return fail(400, { actionError: '잘못된 조건 데이터' });
			}
		}

		const { error: err } = await locals.supabase
			.from('approval_rules')
			.update({
				name,
				form_id: formId,
				condition_json: conditionJson,
				line_template_json: lineTemplate,
				priority
			})
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
			.from('approval_rules')
			.delete()
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		return { ok: true };
	},

	toggle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const active = fd.get('active')?.toString() === 'true';
		if (!id) return fail(400);

		await locals.supabase
			.from('approval_rules')
			.update({ is_active: active })
			.eq('id', id)
			.eq('tenant_id', tenant.id);

		return { ok: true };
	},

	simulate: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
		if (!tenant) return fail(403);

		const fd = await request.formData();
		const formId = fd.get('formId')?.toString();
		let sampleContent: Record<string, unknown> = {};
		try {
			sampleContent = JSON.parse(fd.get('sampleContent')?.toString() ?? '{}');
		} catch {
			/* empty */
		}

		if (!formId) return fail(400, { simulateError: '양식을 선택하세요' });

		const { data: result, error: rpcErr } = await locals.supabase
			.rpc('fn_resolve_approval_line', {
				p_tenant_id: tenant.id,
				p_form_id: formId,
				p_content: sampleContent
			});

		if (rpcErr) {
			return { simulateResult: { approvers: [], ruleName: null, error: rpcErr.message } };
		}

		const lineItems = (result ?? []) as { userId: string; stepType: string }[];

		if (lineItems.length === 0) {
			return { simulateResult: { approvers: [], ruleName: null, error: '매칭되는 규칙이 없습니다.' } };
		}

		// Profile join
		const userIds = lineItems.map((i) => i.userId);
		const profileMap = await fetchProfilesByIds(locals.supabase, userIds);

		const { data: tmRows } = await locals.supabase
			.from('tenant_members')
			.select('user_id, department_id, job_title_id')
			.eq('tenant_id', tenant.id)
			.in('user_id', userIds);

		const { data: depts } = await locals.supabase
			.from('departments')
			.select('id, name')
			.eq('tenant_id', tenant.id);

		const { data: jts } = await locals.supabase
			.from('job_titles')
			.select('id, name')
			.eq('tenant_id', tenant.id);

		const tmMap = new Map((tmRows ?? []).map((r) => [r.user_id as string, r]));
		const deptMap = new Map((depts ?? []).map((d) => [d.id as string, d.name as string]));
		const jtMap = new Map((jts ?? []).map((j) => [j.id as string, j.name as string]));

		const approvers = lineItems.map((item) => {
			const p = profileMap.get(item.userId);
			const tm = tmMap.get(item.userId);
			return {
				userId: item.userId,
				displayName: p?.display_name ?? '(알 수 없음)',
				departmentName: tm?.department_id ? (deptMap.get(tm.department_id as string) ?? null) : null,
				jobTitleName: tm?.job_title_id ? (jtMap.get(tm.job_title_id as string) ?? null) : null,
				stepType: item.stepType
			};
		});

		// 매칭 규칙 이름
		const { data: matchedRule } = await locals.supabase
			.from('approval_rules')
			.select('name')
			.eq('tenant_id', tenant.id)
			.eq('is_active', true)
			.or(`form_id.eq.${formId},form_id.is.null`)
			.order('priority', { ascending: true })
			.limit(1)
			.maybeSingle();

		return {
			simulateResult: {
				approvers,
				ruleName: matchedRule?.name ?? null,
				error: null
			}
		};
	}
};
