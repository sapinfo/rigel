import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

/**
 * Entry redirect:
 *   - unauthenticated → /login (authGuard handles this already, but kept for safety)
 *   - authenticated, no tenants → /onboarding/create-tenant
 *   - authenticated, has tenants → /t/{defaultOrFirstSlug}/approval/inbox
 */
export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) redirect(303, '/login');

  const { data: memberships } = await locals.supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug, name)')
    .eq('user_id', locals.user.id);

  if (!memberships || memberships.length === 0) {
    redirect(303, '/onboarding/create-tenant');
  }

  const { data: profile } = await locals.supabase
    .from('profiles')
    .select('default_tenant_id')
    .eq('id', locals.user.id)
    .single();

  const tenants = memberships.map((m) => ({
    id: (m.tenant as unknown as { id: string }).id,
    slug: (m.tenant as unknown as { slug: string }).slug
  }));

  const target =
    tenants.find((t) => t.id === profile?.default_tenant_id) ?? tenants[0];

  redirect(303, `/t/${target.slug}`);
};
