import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
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

  const dateParam = url.searchParams.get('date');
  const selectedDate = dateParam ?? new Date().toISOString().slice(0, 10);

  const { data: rooms } = await locals.supabase
    .from('meeting_rooms')
    .select('id, name, location, capacity, is_active')
    .eq('tenant_id', currentTenant.id)
    .eq('is_active', true)
    .order('name');

  // Reservations for selected date
  const dayStart = new Date(selectedDate + 'T00:00:00+09:00');
  const dayEnd = new Date(selectedDate + 'T23:59:59+09:00');

  const { data: reservations } = await locals.supabase
    .from('room_reservations')
    .select('id, room_id, title, reserved_by, start_at, end_at')
    .eq('tenant_id', currentTenant.id)
    .gte('start_at', dayStart.toISOString())
    .lte('start_at', dayEnd.toISOString())
    .order('start_at');

  const userIds = (reservations ?? []).map((r) => r.reserved_by as string);
  const profiles = await fetchProfilesByIds(locals.supabase, userIds);

  return {
    rooms: (rooms ?? []).map((r) => ({
      id: r.id as string,
      name: r.name as string,
      location: (r.location as string | null) ?? null,
      capacity: (r.capacity as number | null) ?? null
    })),
    reservations: (reservations ?? []).map((r) => ({
      id: r.id as string,
      room_id: r.room_id as string,
      title: r.title as string,
      reserved_by_name: profiles.get(r.reserved_by as string)?.display_name ?? '',
      start_at: r.start_at as string,
      end_at: r.end_at as string
    })),
    selectedDate
  };
};

export const actions: Actions = {
  reserve: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant) return fail(403);

    const fd = await request.formData();
    const room_id = fd.get('room_id')?.toString();
    const title = fd.get('title')?.toString()?.trim();
    const start_at = fd.get('start_at')?.toString();
    const end_at = fd.get('end_at')?.toString();

    if (!room_id || !title || !start_at || !end_at) return fail(400, { error: '필수 값을 입력하세요' });

    const { error: err } = await locals.supabase
      .from('room_reservations')
      .insert({
        room_id,
        tenant_id: tenant.id,
        title,
        reserved_by: locals.user.id,
        start_at: new Date(start_at).toISOString(),
        end_at: new Date(end_at).toISOString()
      });

    if (err) {
      if (err.message.includes('exclusion') || err.code === '23P01') {
        return fail(400, { error: '해당 시간에 이미 예약이 있습니다' });
      }
      return fail(400, { error: err.message });
    }
    return { ok: true };
  },

  cancelReservation: async ({ request, locals }) => {
    if (!locals.user) return fail(401);
    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('room_reservations')
      .delete()
      .eq('id', id);
    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
