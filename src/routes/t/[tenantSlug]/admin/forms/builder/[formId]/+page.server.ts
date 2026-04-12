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

		// 현재 양식 조회
		const { data: form } = await locals.supabase
			.from('approval_forms')
			.select('id, is_published, version, schema, code, name, description')
			.eq('id', params.formId)
			.eq('tenant_id', currentTenant.id)
			.maybeSingle();

		if (!form) return fail(404, { actionError: '양식을 찾을 수 없습니다' });

		if (form.is_published) {
			// 이미 발행된 양식 → 새 버전 INSERT (기존 문서 보호)
			const { data: newForm, error: err } = await locals.supabase
				.from('approval_forms')
				.insert({
					tenant_id: currentTenant.id,
					code: form.code,
					name: form.name,
					description: form.description,
					schema: form.schema,
					version: (form.version as number) + 1,
					parent_form_id: form.id,
					is_published: true
				})
				.select('id')
				.single();

			if (err) return fail(500, { actionError: err.message });
			return { ok: true, published: true, newFormId: newForm?.id };
		} else {
			// 미발행 → 단순 발행
			const { error: err } = await locals.supabase
				.from('approval_forms')
				.update({ is_published: true, updated_at: new Date().toISOString() })
				.eq('id', params.formId)
				.eq('tenant_id', currentTenant.id);

			if (err) return fail(500, { actionError: err.message });
			return { ok: true, published: true };
		}
	}
};
