import { error, fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { FormSchema } from '$lib/types/approval';
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

export const load: PageServerLoad = async ({ locals, params, parent }) => {
	const { currentTenant } = await parent();
	if (!currentTenant) error(404);

	const { data: form } = await locals.supabase
		.from('approval_forms')
		.select('id, code, name, description, schema, version, parent_form_id, is_published')
		.eq('id', params.formId)
		.eq('tenant_id', currentTenant.id)
		.maybeSingle();

	if (!form) error(404, '양식을 찾을 수 없습니다');

	return {
		form: {
			id: form.id as string,
			code: form.code as string,
			name: form.name as string,
			description: (form.description as string | null) ?? '',
			schema: form.schema as unknown as FormSchema,
			version: form.version as number,
			parentFormId: (form.parent_form_id as string | null) ?? null,
			isPublished: form.is_published as boolean
		}
	};
};

export const actions: Actions = {
	save: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const fd = await request.formData();
		const schemaRaw = fd.get('schema')?.toString();
		if (!schemaRaw) return fail(400, { actionError: 'schema 누락' });

		let schema: FormSchema;
		try {
			schema = JSON.parse(schemaRaw);
		} catch {
			return fail(400, { actionError: '잘못된 JSON' });
		}

		const { error: err } = await locals.supabase
			.from('approval_forms')
			.update({ schema, updated_at: new Date().toISOString() })
			.eq('id', params.formId)
			.eq('tenant_id', currentTenant.id);

		if (err) return fail(500, { actionError: err.message });
		return { ok: true };
	},

	publish: async ({ locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const { error: err } = await locals.supabase
			.from('approval_forms')
			.update({ is_published: true, updated_at: new Date().toISOString() })
			.eq('id', params.formId)
			.eq('tenant_id', currentTenant.id);

		if (err) return fail(500, { actionError: err.message });
		return { ok: true, published: true };
	}
};
