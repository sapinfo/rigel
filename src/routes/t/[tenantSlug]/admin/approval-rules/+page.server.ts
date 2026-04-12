import { error, fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';

async function resolveTenant(
	supabase: SupabaseClient,
	userId: string,
	slug: string
): Promise<{ id: string; slug: string } | null> {
	const { data } = await supabase
		.from('tenant_members')
		.select('tenant:tenants!inner(id, slug)')
		.eq('user_id', userId)
		.eq('tenant.slug', slug)
		.maybeSingle();
	if (!data) return null;
	const t = data.tenant as unknown as { id: string; slug: string };
	return { id: t.id, slug: t.slug };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();
	if (!currentTenant) error(404);

	const { data: rules } = await locals.supabase
		.from('approval_rules')
		.select('id, name, form_id, condition_json, line_template_json, priority, is_active, created_at')
		.eq('tenant_id', currentTenant.id)
		.order('priority', { ascending: true });

	const { data: forms } = await locals.supabase
		.from('approval_forms')
		.select('id, name, code')
		.eq('tenant_id', currentTenant.id)
		.eq('is_published', true);

	return {
		rules: rules ?? [],
		availableForms: forms ?? []
	};
};

export const actions: Actions = {
	create: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const fd = await request.formData();
		const name = fd.get('name')?.toString()?.trim();
		const formId = fd.get('form_id')?.toString() || null;
		const priority = parseInt(fd.get('priority')?.toString() ?? '100', 10);
		const lineTemplateRaw = fd.get('line_template_json')?.toString();

		if (!name) return fail(400, { actionError: '규칙 이름 필수' });
		if (!lineTemplateRaw) return fail(400, { actionError: '결재선 템플릿 필수' });

		let lineTemplate;
		try {
			lineTemplate = JSON.parse(lineTemplateRaw);
		} catch {
			return fail(400, { actionError: '잘못된 JSON' });
		}

		const { error: err } = await locals.supabase
			.from('approval_rules')
			.insert({
				tenant_id: currentTenant.id,
				name,
				form_id: formId,
				line_template_json: lineTemplate,
				priority,
				is_active: true
			});

		if (err) return fail(500, { actionError: err.message });
		return { ok: true };
	},

	delete: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		if (!id) return fail(400);

		await locals.supabase
			.from('approval_rules')
			.delete()
			.eq('id', id)
			.eq('tenant_id', currentTenant.id);

		return { ok: true };
	},

	toggle: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const fd = await request.formData();
		const id = fd.get('id')?.toString();
		const active = fd.get('active')?.toString() === 'true';
		if (!id) return fail(400);

		await locals.supabase
			.from('approval_rules')
			.update({ is_active: active })
			.eq('id', id)
			.eq('tenant_id', currentTenant.id);

		return { ok: true };
	}
};
