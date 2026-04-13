import { error } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import type { CurrentTenant, TenantRole } from '$lib/types/approval';

/**
 * Resolve tenant context from URL slug + verify membership.
 * This runs for every request under /t/[tenantSlug]/.
 */
export const load: LayoutServerLoad = async ({ locals, params }) => {
  if (!locals.user) error(401, 'Not authenticated');

  const { data, error: err } = await locals.supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug, name)')
    .eq('user_id', locals.user.id)
    .eq('tenant.slug', params.tenantSlug)
    .maybeSingle();

  if (err || !data) {
    error(404, 'Tenant not found or you are not a member');
  }

  const tenant = data.tenant as unknown as { id: string; slug: string; name: string };
  const currentTenant: CurrentTenant = {
    id: tenant.id,
    slug: tenant.slug,
    name: tenant.name,
    role: data.role as TenantRole
  };

  locals.currentTenant = currentTenant;

  // Published forms list for the "New draft" dropdown in the header.
  const { data: formRows } = await locals.supabase
    .from('approval_forms')
    .select('code, name')
    .eq('tenant_id', currentTenant.id)
    .eq('is_published', true)
    .order('name', { ascending: true });

  const forms = (formRows ?? []).map((f) => ({
    code: f.code as string,
    name: f.name as string
  }));

  // v1.3: unread notification count for SSR
  const { count: unreadCount } = await locals.supabase
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', locals.user.id)
    .eq('tenant_id', currentTenant.id)
    .eq('read', false);

  // v3.1: popup announcements for modal
  const { data: popupRows } = await locals.supabase.rpc('get_popup_announcements', {
    p_tenant_id: currentTenant.id
  });
  const popupAnnouncements = (popupRows ?? []).map((a: Record<string, unknown>) => ({
    id: a.id as string,
    title: a.title as string,
    content: a.content as Record<string, unknown>,
    publishedAt: a.published_at as string
  }));

  return { currentTenant, forms, unreadCount: unreadCount ?? 0, popupAnnouncements };
};
