import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) error(401);
  const tenant = locals.currentTenant!;
  if (tenant.role !== 'owner' && tenant.role !== 'admin') error(403);

  // Current month range
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const startDate = new Date(year, month, 1).toISOString().slice(0, 10);
  const endDate = new Date(year, month + 1, 0).toISOString().slice(0, 10);

  // All attendance records for this month
  const { data: records } = await locals.supabase
    .from('attendance_records')
    .select('*, profiles:user_id(full_name)')
    .eq('tenant_id', tenant.id)
    .gte('work_date', startDate)
    .lte('work_date', endDate)
    .order('work_date', { ascending: false });

  return {
    records: (records ?? []).map((r) => ({
      ...r,
      userName: (r.profiles as { full_name: string } | null)?.full_name ?? '(알 수 없음)'
    })),
    year,
    month: month + 1
  };
};
