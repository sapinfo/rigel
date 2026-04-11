import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';

async function resolveTenant(
  supabase: SupabaseClient,
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
  const t = data.tenant as unknown as { id: string; slug: string };
  return { id: t.id, role: data.role as string };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();

  const { data: forms } = await locals.supabase
    .from('approval_forms')
    .select('id, code, name, description, is_published, version, updated_at')
    .eq('tenant_id', currentTenant.id)
    .order('name', { ascending: true });

  return {
    forms: (forms ?? []).map((f) => ({
      id: f.id as string,
      code: f.code as string,
      name: f.name as string,
      description: (f.description as string | null) ?? null,
      is_published: f.is_published as boolean,
      version: f.version as number,
      updated_at: f.updated_at as string
    }))
  };
};

export const actions: Actions = {
  togglePublish: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    const publish = fd.get('publish') === 'true';
    if (!id) return fail(400, { error: 'id 누락' });

    const { error: err } = await locals.supabase
      .from('approval_forms')
      .update({ is_published: publish, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  deleteForm: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400, { error: 'id 누락' });

    // FK restrict: 이미 문서가 참조하는 양식은 삭제 불가
    const { error: err } = await locals.supabase
      .from('approval_forms')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) {
      return fail(400, {
        error: err.code === '23503'
          ? '이미 사용 중인 양식은 삭제할 수 없습니다 (문서가 존재)'
          : err.message
      });
    }
    return { ok: true };
  }
};
