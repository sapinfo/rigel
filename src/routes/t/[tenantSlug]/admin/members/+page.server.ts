import { fail } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { Actions, PageServerLoad } from './$types';
import type { TenantRole } from '$lib/types/approval';

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

const inviteSchema = z.object({
  email: z.string().trim().email('올바른 이메일 형식이 아닙니다'),
  role: z.enum(['admin', 'member']).default('member')
});

const updateRoleSchema = z.object({
  user_id: z.string().uuid(),
  role: z.enum(['owner', 'admin', 'member'])
});

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();
  const tenantId = currentTenant.id;

  // 멤버 목록 (2-query pattern)
  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, role, job_title, joined_at, department_id')
    .eq('tenant_id', tenantId);

  const profileMap = await fetchProfilesByIds(
    locals.supabase,
    (memberRows ?? []).map((m) => m.user_id as string)
  );

  const members = (memberRows ?? []).map((m) => {
    const p = profileMap.get(m.user_id as string);
    return {
      user_id: m.user_id as string,
      role: m.role as TenantRole,
      job_title: (m.job_title as string | null) ?? null,
      department_id: (m.department_id as string | null) ?? null,
      joined_at: m.joined_at as string,
      display_name: p?.display_name ?? '(알 수 없음)',
      email: p?.email ?? ''
    };
  });

  // 대기중인 초대
  const { data: invites } = await locals.supabase
    .from('tenant_invitations')
    .select('id, email, role, token, expires_at, accepted_at, created_at')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });

  const invitations = (invites ?? []).map((i) => ({
    id: i.id as string,
    email: i.email as string,
    role: i.role as TenantRole,
    token: i.token as string,
    expires_at: i.expires_at as string,
    accepted_at: (i.accepted_at as string | null) ?? null,
    created_at: i.created_at as string
  }));

  // 부서 목록 (필터용)
  const { data: depts } = await locals.supabase
    .from('departments')
    .select('id, name')
    .eq('tenant_id', tenantId)
    .order('name');

  return { members, invitations, departments: (depts ?? []).map((d) => ({ id: d.id as string, name: d.name as string })) };
};

export const actions: Actions = {
  invite: async ({ request, locals, params, url }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const parsed = inviteSchema.safeParse({
      email: fd.get('email'),
      role: fd.get('role') ?? 'member'
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed) });
    }

    const { data, error: err } = await locals.supabase
      .from('tenant_invitations')
      .insert({
        tenant_id: tenant.id,
        email: parsed.data.email,
        role: parsed.data.role,
        invited_by: locals.user.id
      })
      .select('token')
      .single();

    if (err) {
      return fail(400, { errors: formError(err.message || '초대 생성 실패') });
    }

    return {
      invited: true,
      inviteLink: `${url.origin}/invite/${data!.token}`
    };
  },

  cancelInvite: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400);

    await locals.supabase
      .from('tenant_invitations')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    return { ok: true };
  },

  updateRole: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || tenant.role !== 'owner') {
      return fail(403, { errors: formError('owner만 역할 변경 가능') });
    }

    const fd = await request.formData();
    const parsed = updateRoleSchema.safeParse({
      user_id: fd.get('user_id'),
      role: fd.get('role')
    });
    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed) });
    }

    // 본인을 owner에서 내려가게 하는 건 금지 (다른 owner가 있어야)
    if (parsed.data.user_id === locals.user.id && parsed.data.role !== 'owner') {
      return fail(400, { errors: formError('본인의 owner 권한은 직접 변경할 수 없습니다') });
    }

    const { error: err } = await locals.supabase
      .from('tenant_members')
      .update({ role: parsed.data.role })
      .eq('tenant_id', tenant.id)
      .eq('user_id', parsed.data.user_id);

    if (err) return fail(400, { errors: formError(err.message) });
    return { ok: true };
  },

  removeMember: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || tenant.role !== 'owner') {
      return fail(403, { errors: formError('owner만 멤버 제거 가능') });
    }

    const fd = await request.formData();
    const userId = fd.get('user_id')?.toString();
    if (!userId) return fail(400);
    if (userId === locals.user.id) {
      return fail(400, { errors: formError('본인을 제거할 수 없습니다') });
    }

    const { error: err } = await locals.supabase
      .from('tenant_members')
      .delete()
      .eq('tenant_id', tenant.id)
      .eq('user_id', userId);

    if (err) {
      return fail(400, {
        errors: formError(
          err.code === '23503'
            ? '이미 결재 참여 중인 멤버는 제거할 수 없습니다'
            : err.message
        )
      });
    }
    return { ok: true };
  }
};
