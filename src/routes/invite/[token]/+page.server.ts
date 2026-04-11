import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params }) => {
  // Public route — 로그인 없이 접근 가능.
  // tenant_invitations RLS는 admin 전용이므로 SECURITY DEFINER RPC 경유.
  const { data: rows, error: err } = await locals.supabase
    .rpc('fn_get_invitation_by_token', { p_token: params.token });

  const authenticated = !!locals.user;
  const userEmail = locals.user?.email ?? null;

  if (err || !rows || (Array.isArray(rows) && rows.length === 0)) {
    return {
      status: 'not_found' as const,
      invitation: null,
      authenticated,
      userEmail
    };
  }

  const row = (Array.isArray(rows) ? rows[0] : rows) as {
    invitation_id: string;
    email: string;
    role: string;
    expires_at: string;
    accepted_at: string | null;
    tenant_id: string;
    tenant_slug: string;
    tenant_name: string;
  };

  const inv = {
    id: row.invitation_id,
    email: row.email,
    role: row.role,
    expires_at: row.expires_at,
    accepted_at: row.accepted_at,
    tenant: {
      id: row.tenant_id,
      slug: row.tenant_slug,
      name: row.tenant_name
    }
  };

  const now = new Date();
  if (new Date(inv.expires_at) < now) {
    return { status: 'expired' as const, invitation: inv, authenticated, userEmail };
  }

  if (inv.accepted_at) {
    return {
      status: 'already_accepted' as const,
      invitation: inv,
      authenticated,
      userEmail
    };
  }

  return { status: 'pending' as const, invitation: inv, authenticated, userEmail };
};

export const actions: Actions = {
  accept: async ({ locals, params }) => {
    if (!locals.user) {
      return fail(401, { error: '로그인이 필요합니다' });
    }

    const { data: tenant, error: rpcErr } = await locals.supabase
      .rpc('fn_accept_invitation', { p_token: params.token })
      .single();

    if (rpcErr) {
      return fail(400, { error: rpcErr.message || '초대 수락 실패' });
    }

    redirect(303, `/t/${(tenant as { slug: string }).slug}/approval/inbox`);
  }
};
