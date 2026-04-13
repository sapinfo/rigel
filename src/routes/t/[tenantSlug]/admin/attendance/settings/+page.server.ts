import { error, fail } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) error(401);
  const tenant = locals.currentTenant!;
  if (tenant.role !== 'owner' && tenant.role !== 'admin') error(403);

  const { data: settings } = await locals.supabase
    .from('attendance_settings')
    .select('*')
    .eq('tenant_id', tenant.id)
    .maybeSingle();

  return {
    settings: settings ?? {
      tenant_id: tenant.id,
      work_start_time: '09:00',
      work_end_time: '18:00',
      late_threshold_minutes: 10
    }
  };
};

export const actions: Actions = {
  save: async ({ request, locals }) => {
    if (!locals.user) error(401);
    const tenant = locals.currentTenant!;
    if (tenant.role !== 'owner' && tenant.role !== 'admin') error(403);

    const fd = await request.formData();
    const payload = {
      tenant_id: tenant.id,
      work_start_time: fd.get('work_start_time') as string,
      work_end_time: fd.get('work_end_time') as string,
      late_threshold_minutes: Number(fd.get('late_threshold_minutes')),
      updated_at: new Date().toISOString()
    };

    const { error: err } = await locals.supabase
      .from('attendance_settings')
      .upsert(payload, { onConflict: 'tenant_id' });

    if (err) return fail(400, { message: err.message });
    return { success: true };
  }
};
