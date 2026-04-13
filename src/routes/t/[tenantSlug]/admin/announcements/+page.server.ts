import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';

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

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();

  const { data: announcements } = await locals.supabase
    .from('announcements')
    .select('id, title, author_id, is_popup, require_read_confirm, published_at, expires_at, created_at')
    .eq('tenant_id', currentTenant.id)
    .order('created_at', { ascending: false });

  const authorIds = (announcements ?? []).map((a) => a.author_id as string);
  const profiles = await fetchProfilesByIds(locals.supabase, authorIds);

  // Read counts per announcement
  const annIds = (announcements ?? []).map((a) => a.id as string);
  let readCounts = new Map<string, number>();
  if (annIds.length > 0) {
    const { data: reads } = await locals.supabase
      .from('announcement_reads')
      .select('announcement_id')
      .in('announcement_id', annIds);
    if (reads) {
      for (const r of reads) {
        const aid = r.announcement_id as string;
        readCounts.set(aid, (readCounts.get(aid) ?? 0) + 1);
      }
    }
  }

  // Total member count for read ratio
  const { count: memberCount } = await locals.supabase
    .from('tenant_members')
    .select('*', { count: 'exact', head: true })
    .eq('tenant_id', currentTenant.id);

  return {
    announcements: (announcements ?? []).map((a) => ({
      id: a.id as string,
      title: a.title as string,
      author_name: profiles.get(a.author_id as string)?.display_name ?? '',
      is_popup: a.is_popup as boolean,
      require_read_confirm: a.require_read_confirm as boolean,
      published_at: (a.published_at as string | null) ?? null,
      read_count: readCounts.get(a.id as string) ?? 0,
      created_at: a.created_at as string
    })),
    memberCount: memberCount ?? 0
  };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const title = fd.get('title')?.toString()?.trim();
    const content = fd.get('content')?.toString() ?? '{}';
    const is_popup = fd.get('is_popup') === 'on';
    const require_read_confirm = fd.get('require_read_confirm') === 'on';
    const publish = fd.get('publish') === 'true';
    const expires_at = fd.get('expires_at')?.toString() || null;

    if (!title) return fail(400, { error: '제목을 입력하세요' });

    const { error: err } = await locals.supabase
      .from('announcements')
      .insert({
        tenant_id: tenant.id,
        title,
        content: JSON.parse(content),
        author_id: locals.user.id,
        is_popup,
        require_read_confirm,
        published_at: publish ? new Date().toISOString() : null,
        expires_at
      });

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  publish: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('announcements')
      .update({ published_at: new Date().toISOString() })
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  },

  delete: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    const { error: err } = await locals.supabase
      .from('announcements')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
