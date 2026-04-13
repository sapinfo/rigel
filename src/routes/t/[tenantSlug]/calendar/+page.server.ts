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

export const load: PageServerLoad = async ({ locals, parent, url }) => {
  const { currentTenant } = await parent();

  // Month from query param or current
  const yearParam = url.searchParams.get('year');
  const monthParam = url.searchParams.get('month');
  const now = new Date();
  const year = yearParam ? parseInt(yearParam) : now.getFullYear();
  const month = monthParam ? parseInt(monthParam) : now.getMonth() + 1;

  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59);

  const { data: events } = await locals.supabase
    .from('calendar_events')
    .select('id, title, description, start_at, end_at, all_day, event_type, color, created_by')
    .eq('tenant_id', currentTenant.id)
    .gte('start_at', startDate.toISOString())
    .lte('start_at', endDate.toISOString())
    .order('start_at');

  const isAdmin = currentTenant.role === 'owner' || currentTenant.role === 'admin';

  return {
    events: (events ?? []).map((e) => ({
      id: e.id as string,
      title: e.title as string,
      description: (e.description as string | null) ?? null,
      start_at: e.start_at as string,
      end_at: e.end_at as string,
      all_day: e.all_day as boolean,
      event_type: e.event_type as string,
      color: (e.color as string | null) ?? null,
      created_by: e.created_by as string
    })),
    year,
    month,
    isAdmin
  };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(403);

    const fd = await request.formData();
    const title = fd.get('title')?.toString()?.trim();
    const start_at = fd.get('start_at')?.toString();
    const end_at = fd.get('end_at')?.toString();
    const all_day = fd.get('all_day') === 'on';
    const event_type = fd.get('event_type')?.toString() ?? 'personal';
    const color = fd.get('color')?.toString() || null;
    const description = fd.get('description')?.toString()?.trim() || null;

    if (!title || !start_at || !end_at) return fail(400, { error: '필수 값을 입력하세요' });

    // Non-admin can only create personal events
    if (event_type !== 'personal' && !['owner', 'admin'].includes(tenant.role)) {
      return fail(403, { error: '개인 일정만 등록할 수 있습니다' });
    }

    const { error: err } = await locals.supabase
      .from('calendar_events')
      .insert({
        tenant_id: tenant.id,
        title,
        description,
        start_at: new Date(start_at).toISOString(),
        end_at: new Date(end_at).toISOString(),
        all_day,
        event_type,
        color,
        created_by: locals.user.id
      });

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  delete: async ({ request, locals }) => {
    if (!locals.user) return fail(401);
    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('calendar_events')
      .delete()
      .eq('id', id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
