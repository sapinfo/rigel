import { error, fail, redirect } from '@sveltejs/kit';
import {
  delegationRuleSchema,
  coerceDelegationRuleFormData
} from '$lib/server/schemas/delegationRule';
import { zodErrors, formError } from '$lib/forms';
import { fetchDelegationRule } from '$lib/server/queries/delegations';
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

function toInputDate(iso: string | null): string {
  if (!iso) return '';
  // HTML <input type="date"> 는 YYYY-MM-DD. 저장 시 KST 하루 경계로 저장하므로
  // 같은 타임존(KST)에서 다시 날짜 부분만 추출해야 역변환이 일관됨.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date(iso));
}

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { currentTenant } = await parent();
  const rule = await fetchDelegationRule(locals.supabase, currentTenant.id, params.id);
  if (!rule) error(404, '전결 규칙을 찾을 수 없습니다');

  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, job_title')
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
      job_title: (m.job_title as string | null) ?? null
    };
  });

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

  return {
    rule,
    members,
    forms,
    initialValues: {
      delegator_user_id: rule.delegator_user_id,
      delegate_user_id: rule.delegate_user_id,
      form_id: rule.form_id ?? '',
      amount_limit: rule.amount_limit === null ? '' : String(rule.amount_limit),
      effective_from: toInputDate(rule.effective_from),
      effective_to: toInputDate(rule.effective_to)
    }
  };
};

export const actions: Actions = {
  update: async ({ request, locals, params }) => {
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

    const { error: err } = await locals.supabase
      .from('delegation_rules')
      .update({
        delegator_user_id: parsed.data.delegator_user_id,
        delegate_user_id: parsed.data.delegate_user_id,
        form_id: parsed.data.form_id,
        amount_limit: parsed.data.amount_limit,
        effective_from: parsed.data.effective_from.toISOString(),
        effective_to: parsed.data.effective_to?.toISOString() ?? null,
        updated_at: new Date().toISOString()
      })
      .eq('id', params.id)
      .eq('tenant_id', tenant.id);

    if (err) {
      const msg =
        err.code === '23514'
          ? '입력값이 제약조건을 위반했습니다 (위임자/대리 또는 기간 확인)'
          : err.message || '전결 규칙 수정 실패';
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
