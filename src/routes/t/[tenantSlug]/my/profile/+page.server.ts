import { error, fail } from '@sveltejs/kit';
import type { PageServerLoad, Actions } from './$types';

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();

  const { data: profile } = await locals.supabase
    .from('employee_profiles')
    .select('*')
    .eq('user_id', locals.user.id)
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  const { data: baseProfile } = await locals.supabase
    .from('profiles')
    .select('display_name')
    .eq('id', locals.user.id)
    .maybeSingle();

  return {
    profile: profile ?? null,
    fullName: (baseProfile?.display_name as string) ?? '',
    email: locals.user.email ?? ''
  };
};

export const actions: Actions = {
  save: async ({ request, locals, parent }) => {
    if (!locals.user) error(401, 'Not authenticated');
    const { currentTenant } = await parent();

    const fd = await request.formData();
    const payload = {
      user_id: locals.user.id,
      tenant_id: currentTenant.id,
      employee_number: (fd.get('employee_number') as string) || null,
      hire_date: (fd.get('hire_date') as string) || null,
      phone_office: (fd.get('phone_office') as string) || null,
      phone_mobile: (fd.get('phone_mobile') as string) || null,
      job_title: (fd.get('job_title') as string) || null,
      job_position: (fd.get('job_position') as string) || null,
      bio: (fd.get('bio') as string) || null,
      updated_at: new Date().toISOString()
    };

    const { error: err } = await locals.supabase
      .from('employee_profiles')
      .upsert(payload, { onConflict: 'user_id' });

    if (err) return fail(400, { message: err.message });
    return { success: true };
  }
};
