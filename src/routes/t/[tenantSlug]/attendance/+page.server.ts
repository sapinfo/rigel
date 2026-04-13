import { error, fail } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';

export const load: PageServerLoad = async ({ locals, params }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const tenantId = locals.currentTenant!.id;

  // Current month range (KST)
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const startDate = new Date(year, month, 1).toISOString().slice(0, 10);
  const endDate = new Date(year, month + 1, 0).toISOString().slice(0, 10);

  const { data: records } = await locals.supabase
    .from('attendance_records')
    .select('*')
    .eq('tenant_id', tenantId)
    .eq('user_id', locals.user.id)
    .gte('work_date', startDate)
    .lte('work_date', endDate)
    .order('work_date', { ascending: false });

  // Today's record
  const today = new Date().toLocaleDateString('sv-SE'); // YYYY-MM-DD
  const todayRecord = (records ?? []).find((r) => r.work_date === today) ?? null;

  return {
    records: records ?? [],
    todayRecord,
    year,
    month: month + 1 // 1-indexed
  };
};

export const actions: Actions = {
  clockIn: async ({ locals }) => {
    if (!locals.user) error(401);
    const tenantId = locals.currentTenant!.id;

    const { data, error: err } = await locals.supabase.rpc('fn_clock_in', {
      p_tenant_id: tenantId
    });

    if (err) return fail(400, { message: err.message });
    return { success: true, record: data };
  },

  clockOut: async ({ locals }) => {
    if (!locals.user) error(401);
    const tenantId = locals.currentTenant!.id;

    const { data, error: err } = await locals.supabase.rpc('fn_clock_out', {
      p_tenant_id: tenantId
    });

    if (err) return fail(400, { message: err.message });
    return { success: true, record: data };
  }
};
