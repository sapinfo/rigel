import { error, fail } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { PageServerLoad, Actions } from './$types';

// CLAUDE.md 규칙: Actions는 parent() 없어 locals.currentTenant 는 null.
// tenantSlug + role을 DB에서 직접 해석.
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
  return {
    id: (data.tenant as unknown as { id: string }).id,
    role: data.role as string
  };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();
  if (currentTenant.role !== 'owner' && currentTenant.role !== 'admin') error(403, 'Forbidden');

  const { data: settings } = await locals.supabase
    .from('attendance_settings')
    .select('*')
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  return {
    settings: settings ?? {
      tenant_id: currentTenant.id,
      work_start_time: '09:00',
      work_end_time: '18:00',
      late_threshold_minutes: 10
    }
  };
};

export const actions: Actions = {
  save: async ({ request, locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');

    const tenant = await resolveTenantAdmin(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(404, { message: 'Tenant not found' });
    if (tenant.role !== 'owner' && tenant.role !== 'admin') {
      return fail(403, { message: 'Forbidden' });
    }

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
