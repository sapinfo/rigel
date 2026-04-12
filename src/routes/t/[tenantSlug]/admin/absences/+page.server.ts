import { fail } from '@sveltejs/kit';
import { fetchAbsences } from '$lib/server/queries/absences';
import type { Actions, PageServerLoad } from './$types';

async function resolveTenant(
  supabase: any,
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
  const t = data.tenant as { id: string; slug: string };
  return { id: t.id, role: data.role };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();
  const absences = await fetchAbsences(locals.supabase, currentTenant.id);
  return { absences };
};

export const actions: Actions = {
  deleteAbsence: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400, { error: 'id 누락' });

    const { error: err } = await locals.supabase
      .from('user_absences')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
