import { error, fail, redirect } from '@sveltejs/kit';
import { formMetaSchema } from '$lib/server/schemas/formSchema';
import { zodErrors, formError } from '$lib/forms';
import type { Actions, PageServerLoad } from './$types';

async function resolveTenant(
  supabase: any,
  userId: string,
  slug: string
): Promise<{ id: string; role: string } | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  const t = data.tenant as { id: string; slug: string };
  return { id: t.id, role: data.role };
}

export const load: PageServerLoad = async ({ locals, params, parent }) => {
  const { currentTenant } = await parent();

  const { data: form, error: err } = await locals.supabase
    .from('approval_forms')
    .select('id, code, name, description, schema, is_published, version')
    .eq('id', params.id)
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  if (err || !form) error(404, '양식을 찾을 수 없습니다');

  return {
    form: {
      id: form.id as string,
      code: form.code as string,
      name: form.name as string,
      description: (form.description as string | null) ?? '',
      schemaJson: JSON.stringify(form.schema, null, 2),
      is_published: form.is_published as boolean,
      version: form.version as number
    }
  };
};

export const actions: Actions = {
  default: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const schemaRaw = fd.get('schema')?.toString() ?? '';
    let schemaJson: unknown;
    try {
      schemaJson = JSON.parse(schemaRaw);
    } catch {
      return fail(400, {
        errors: formError('JSON 형식 오류'),
        values: {
          code: fd.get('code')?.toString() ?? '',
          name: fd.get('name')?.toString() ?? '',
          description: fd.get('description')?.toString() ?? '',
          schema: schemaRaw
        }
      });
    }

    const parsed = formMetaSchema.safeParse({
      code: fd.get('code')?.toString(),
      name: fd.get('name')?.toString(),
      description: fd.get('description')?.toString() || null,
      schema: schemaJson,
      is_published: fd.get('is_published') === 'on'
    });

    if (!parsed.success) {
      return fail(400, {
        errors: zodErrors(parsed),
        values: {
          code: fd.get('code')?.toString() ?? '',
          name: fd.get('name')?.toString() ?? '',
          description: fd.get('description')?.toString() ?? '',
          schema: schemaRaw
        }
      });
    }

    const { code, name, description, schema, is_published } = parsed.data;

    // version은 단조 증가 (이미 상신된 문서는 form_schema_snapshot에 의해 독립됨)
    const { data: current } = await locals.supabase
      .from('approval_forms')
      .select('version')
      .eq('id', params.id)
      .eq('tenant_id', tenant.id)
      .single();

    const { error: err } = await locals.supabase
      .from('approval_forms')
      .update({
        code,
        name,
        description,
        schema,
        is_published,
        version: ((current?.version as number | undefined) ?? 1) + 1,
        updated_at: new Date().toISOString()
      })
      .eq('id', params.id)
      .eq('tenant_id', tenant.id);

    if (err) {
      const msg =
        err.code === '23505'
          ? '이미 사용 중인 양식 코드입니다'
          : err.message || '양식 수정 실패';
      return fail(400, {
        errors: formError(msg),
        values: {
          code: fd.get('code')?.toString() ?? '',
          name: fd.get('name')?.toString() ?? '',
          description: fd.get('description')?.toString() ?? '',
          schema: schemaRaw
        }
      });
    }

    redirect(303, `/t/${params.tenantSlug}/admin/forms`);
  }
};
