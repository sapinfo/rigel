import { fail, redirect } from '@sveltejs/kit';
import {
  delegationRuleSchema,
  coerceDelegationRuleFormData
} from '$lib/server/schemas/delegationRule';
import { zodErrors, formError } from '$lib/forms';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
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

  // 멤버 피커용 프로필 목록
  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, role, job_title')
    .eq('tenant_id', currentTenant.id);

  const profileMap = await fetchProfilesByIds(
    locals.supabase,
    (memberRows ?? []).map((m) => m.user_id as string)
  );

  const members = (memberRows ?? []).map((m) => {
    const p = profileMap.get(m.user_id as string);
    return {
      user_id: m.user_id as string,
      display_name: p?.display_name ?? '(알 수 없음)',
      email: p?.email ?? '',
      role: m.role as string,
      job_title: (m.job_title as string | null) ?? null
    };
  });

  // 양식 피커용
  const { data: formRows } = await locals.supabase
    .from('approval_forms')
    .select('id, code, name')
    .eq('tenant_id', currentTenant.id)
    .eq('is_published', true)
    .order('name', { ascending: true });

  const forms = (formRows ?? []).map((f) => ({
    id: f.id as string,
    code: f.code as string,
    name: f.name as string
  }));

  return { members, forms };
};

export const actions: Actions = {
  default: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const parsed = delegationRuleSchema.safeParse(coerceDelegationRuleFormData(fd));

    if (!parsed.success) {
      return fail(400, {
        errors: zodErrors(parsed),
        values: {
          delegator_user_id: fd.get('delegator_user_id')?.toString() ?? '',
          delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
          form_id: fd.get('form_id')?.toString() ?? '',
          amount_limit: fd.get('amount_limit')?.toString() ?? '',
          effective_from: fd.get('effective_from')?.toString() ?? '',
          effective_to: fd.get('effective_to')?.toString() ?? ''
        }
      });
    }

    const { error: err } = await locals.supabase.from('delegation_rules').insert({
      tenant_id: tenant.id,
      delegator_user_id: parsed.data.delegator_user_id,
      delegate_user_id: parsed.data.delegate_user_id,
      form_id: parsed.data.form_id,
      amount_limit: parsed.data.amount_limit,
      effective_from: parsed.data.effective_from.toISOString(),
      effective_to: parsed.data.effective_to?.toISOString() ?? null,
      created_by: locals.user.id
    });

    if (err) {
      const msg =
        err.code === '23514'
          ? '입력값이 제약조건을 위반했습니다 (위임자/대리 또는 기간 확인)'
          : err.message || '전결 규칙 생성 실패';
      return fail(400, {
        errors: formError(msg),
        values: {
          delegator_user_id: fd.get('delegator_user_id')?.toString() ?? '',
          delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
          form_id: fd.get('form_id')?.toString() ?? '',
          amount_limit: fd.get('amount_limit')?.toString() ?? '',
          effective_from: fd.get('effective_from')?.toString() ?? '',
          effective_to: fd.get('effective_to')?.toString() ?? ''
        }
      });
    }

    redirect(303, `/t/${params.tenantSlug}/admin/delegations`);
  }
};
