import { error, fail } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { PageServerLoad, Actions } from './$types';

// CLAUDE.md 규칙: Actions는 parent()가 없어 locals.currentTenant 는 null.
// tenantSlug 로부터 직접 해석하는 inline helper.
async function resolveTenantId(
  supabase: SupabaseClient,
  userId: string,
  slug: string
): Promise<string | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('tenant:tenants!inner(id)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  return (data.tenant as unknown as { id: string }).id;
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const startDate = new Date(year, month, 1).toISOString().slice(0, 10);
  const endDate = new Date(year, month + 1, 0).toISOString().slice(0, 10);

  const { data: records } = await locals.supabase
    .from('attendance_records')
    .select('*')
    .eq('tenant_id', currentTenant.id)
    .eq('user_id', locals.user.id)
    .gte('work_date', startDate)
    .lte('work_date', endDate)
    .order('work_date', { ascending: false });

  const today = new Date().toLocaleDateString('sv-SE');
  const todayRecord = (records ?? []).find((r) => r.work_date === today) ?? null;

  return {
    records: records ?? [],
    todayRecord,
    year,
    month: month + 1
  };
};

export const actions: Actions = {
  clockIn: async ({ locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');

    const tenantId = await resolveTenantId(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenantId) return fail(404, { message: 'Tenant not found' });

    const { data, error: err } = await locals.supabase.rpc('fn_clock_in', {
      p_tenant_id: tenantId
    });

    if (err) return fail(400, { message: err.message });
    return { success: true, record: data };
  },

  clockOut: async ({ locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');

    const tenantId = await resolveTenantId(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenantId) return fail(404, { message: 'Tenant not found' });

    const { data, error: err } = await locals.supabase.rpc('fn_clock_out', {
      p_tenant_id: tenantId
    });

    if (err) return fail(400, { message: err.message });
    return { success: true, record: data };
  }
};
