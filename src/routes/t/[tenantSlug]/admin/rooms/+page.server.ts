import { error, fail } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) error(401);
  const tenant = locals.currentTenant!;
  if (tenant.role !== 'owner' && tenant.role !== 'admin') error(403);

  const { data: rooms } = await locals.supabase
    .from('meeting_rooms')
    .select('*')
    .eq('tenant_id', tenant.id)
    .order('name');

  return { rooms: rooms ?? [] };
};

export const actions: Actions = {
  create: async ({ request, locals }) => {
    if (!locals.user) error(401);
    const tenant = locals.currentTenant!;
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

  update: async ({ request, locals }) => {
    if (!locals.user) error(401);
    const tenant = locals.currentTenant!;
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

  delete: async ({ request, locals }) => {
    if (!locals.user) error(401);
    const tenant = locals.currentTenant!;
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
