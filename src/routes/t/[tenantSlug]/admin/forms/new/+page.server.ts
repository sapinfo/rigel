import { fail, redirect } from '@sveltejs/kit';
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

const TEMPLATE = {
  version: 1,
  fields: [
    {
      id: 'title',
      type: 'text',
      label: '제목',
      required: true,
      maxLength: 200
    },
    {
      id: 'body',
      type: 'textarea',
      label: '내용',
      required: true
    }
  ]
};

export const load: PageServerLoad = async () => {
  return {
    templateJson: JSON.stringify(TEMPLATE, null, 2)
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

    const { error: err } = await locals.supabase.from('approval_forms').insert({
      tenant_id: tenant.id,
      code,
      name,
      description,
      schema,
      default_approval_line: [],
      is_published,
      version: 1
    });

    if (err) {
      const msg =
        err.code === '23505'
          ? '이미 사용 중인 양식 코드입니다'
          : err.message || '양식 생성 실패';
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
