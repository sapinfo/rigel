import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();
  if (currentTenant.role !== 'owner' && currentTenant.role !== 'admin') error(403, 'Forbidden');

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const startDate = new Date(year, month, 1).toISOString().slice(0, 10);
  const endDate = new Date(year, month + 1, 0).toISOString().slice(0, 10);

  const { data: records } = await locals.supabase
    .from('attendance_records')
    .select('*, profiles:user_id(display_name)')
    .eq('tenant_id', currentTenant.id)
    .gte('work_date', startDate)
    .lte('work_date', endDate)
    .order('work_date', { ascending: false });

  return {
    records: (records ?? []).map((r) => ({
      ...r,
      userName: (r.profiles as { display_name: string } | null)?.display_name ?? '(알 수 없음)'
    })),
    year,
    month: month + 1
  };
};
