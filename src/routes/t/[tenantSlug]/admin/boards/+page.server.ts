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

  const { data: boards } = await locals.supabase
    .from('boards')
    .select('id, name, description, board_type, department_id, is_active, sort_order, created_at')
    .eq('tenant_id', currentTenant.id)
    .order('sort_order', { ascending: true });

  const { data: departments } = await locals.supabase
    .from('departments')
    .select('id, name')
    .eq('tenant_id', currentTenant.id)
    .order('name');

  return {
    boards: (boards ?? []).map((b) => ({
      id: b.id as string,
      name: b.name as string,
      description: (b.description as string | null) ?? null,
      board_type: b.board_type as string,
      department_id: (b.department_id as string | null) ?? null,
      is_active: b.is_active as boolean,
      sort_order: b.sort_order as number
    })),
    departments: (departments ?? []).map((d) => ({
      id: d.id as string,
      name: d.name as string
    }))
  };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const name = fd.get('name')?.toString()?.trim();
    const description = fd.get('description')?.toString()?.trim() || null;
    const board_type = fd.get('board_type')?.toString() ?? 'general';
    const department_id = fd.get('department_id')?.toString() || null;

    if (!name) return fail(400, { error: '이름을 입력하세요' });

    const { error: err } = await locals.supabase
      .from('boards')
      .insert({
        tenant_id: tenant.id,
        name,
        description,
        board_type,
        department_id: board_type === 'department' ? department_id : null,
        created_by: locals.user.id
      });

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  update: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    const name = fd.get('name')?.toString()?.trim();
    const description = fd.get('description')?.toString()?.trim() || null;
    const is_active = fd.get('is_active') === 'true';

    if (!id || !name) return fail(400, { error: '필수 값 누락' });

    const { error: err } = await locals.supabase
      .from('boards')
      .update({ name, description, is_active, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  delete: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('boards')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
