import { error, fail } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { PageServerLoad, Actions } from './$types';

// CLAUDE.md: Actions에서 locals.currentTenant 사용 금지 (parent() 미실행)
async function resolveTenantAdmin(
  supabase: SupabaseClient,
  userId: string,
  slug: string
): Promise<{ id: string; role: string } | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  return { id: (data.tenant as unknown as { id: string }).id, role: data.role as string };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();
  if (currentTenant.role !== 'owner' && currentTenant.role !== 'admin') error(403, 'Forbidden');

  const { data: rooms } = await locals.supabase
    .from('meeting_rooms')
    .select('*')
    .eq('tenant_id', currentTenant.id)
    .order('name');

  return { rooms: rooms ?? [] };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');
    const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(404, { message: 'Tenant not found' });
    if (tenant.role !== 'owner' && tenant.role !== 'admin') return fail(403, { message: 'Forbidden' });

    const fd = await request.formData();
    const { error: err } = await locals.supabase.from('meeting_rooms').insert({
      tenant_id: tenant.id,
      name: fd.get('name') as string,
      location: (fd.get('location') as string) || null,
      capacity: fd.get('capacity') ? Number(fd.get('capacity')) : null
    });

    if (err) return fail(400, { message: err.message });
    return { success: true };
  },

  update: async ({ request, locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');
    const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(404, { message: 'Tenant not found' });
    if (tenant.role !== 'owner' && tenant.role !== 'admin') return fail(403, { message: 'Forbidden' });

    const fd = await request.formData();
    const { error: err } = await locals.supabase
      .from('meeting_rooms')
      .update({
        name: fd.get('name') as string,
        location: (fd.get('location') as string) || null,
        capacity: fd.get('capacity') ? Number(fd.get('capacity')) : null,
        is_active: fd.get('is_active') === 'true'
      })
      .eq('id', fd.get('id') as string)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { message: err.message });
    return { success: true };
  },

  delete: async ({ request, locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');
    const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(404, { message: 'Tenant not found' });
    if (tenant.role !== 'owner' && tenant.role !== 'admin') return fail(403, { message: 'Forbidden' });

    const fd = await request.formData();
    const { error: err } = await locals.supabase
      .from('meeting_rooms')
      .delete()
      .eq('id', fd.get('id') as string)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { message: err.message });
    return { success: true };
  }
};
