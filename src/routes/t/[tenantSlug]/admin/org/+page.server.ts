import { fail } from '@sveltejs/kit';
import { z } from 'zod';
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

const deptSchema = z.object({
  name: z.string().trim().min(1).max(100)
});

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();

  const { data: depts } = await locals.supabase
    .from('departments')
    .select('id, name, path, sort_order, created_at')
    .eq('tenant_id', currentTenant.id)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  return {
    departments: (depts ?? []).map((d) => ({
      id: d.id as string,
      name: d.name as string,
      path: d.path as string,
      sort_order: (d.sort_order as number) ?? 0
    }))
  };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const parsed = deptSchema.safeParse({ name: fd.get('name') });
    if (!parsed.success) return fail(400, { errors: zodErrors(parsed) });

    const { name } = parsed.data;
    const path = `/${name.toLowerCase().replace(/\s+/g, '-')}`;

    const { error: err } = await locals.supabase.from('departments').insert({
      tenant_id: tenant.id,
      name,
      path,
      parent_id: null,
      sort_order: 0
    });

    if (err) return fail(400, { errors: formError(err.message) });
    return { ok: true };
  },

  rename: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

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

  remove: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('departments')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { errors: formError(err.message) });
    return { ok: true };
  }
};
