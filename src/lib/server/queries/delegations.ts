import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchProfilesByIds } from './profiles';

/**
 * v1.1 M11: delegation_rules 조회 helper.
 *
 * profiles.ts 패턴 재사용 — embed 대신 2-query join:
 *   1. delegation_rules 행 조회
 *   2. delegator/delegate user_id → profiles 일괄 fetch
 *   3. form_id → approval_forms 조회 (null 섞여있을 수 있음)
 *
 * Embed를 안 쓰는 이유: delegator/delegate는 모두 auth.users FK인데
 * Supabase JS embed는 같은 테이블을 두 방향으로 못 따라감.
 */

export type DelegationRuleRow = {
  id: string;
  tenant_id: string;
  delegator_user_id: string;
  delegate_user_id: string;
  form_id: string | null;
  amount_limit: number | null;
  effective_from: string;
  effective_to: string | null;
  created_at: string;
  updated_at: string;
  created_by: string;
};

export type DelegationRuleListItem = DelegationRuleRow & {
  delegator: { display_name: string; email: string };
  delegate: { display_name: string; email: string };
  form: { id: string; code: string; name: string } | null;
};

export async function fetchDelegationRules(
  supabase: SupabaseClient,
  tenantId: string
): Promise<DelegationRuleListItem[]> {
  const { data: rows } = await supabase
    .from('delegation_rules')
    .select(
      'id, tenant_id, delegator_user_id, delegate_user_id, form_id, amount_limit, effective_from, effective_to, created_at, updated_at, created_by'
    )
    .eq('tenant_id', tenantId)
    .order('effective_from', { ascending: false });

  if (!rows || rows.length === 0) return [];

  const userIds = new Set<string>();
  const formIds = new Set<string>();
  for (const r of rows) {
    userIds.add(r.delegator_user_id as string);
    userIds.add(r.delegate_user_id as string);
    if (r.form_id) formIds.add(r.form_id as string);
  }

  const profileMap = await fetchProfilesByIds(supabase, Array.from(userIds));

  let formMap = new Map<string, { id: string; code: string; name: string }>();
  if (formIds.size > 0) {
    const { data: forms } = await supabase
      .from('approval_forms')
      .select('id, code, name')
      .in('id', Array.from(formIds));
    formMap = new Map(
      (forms ?? []).map((f) => [
        f.id as string,
        {
          id: f.id as string,
          code: f.code as string,
          name: f.name as string
        }
      ])
    );
  }

  return rows.map((r) => {
    const delegator = profileMap.get(r.delegator_user_id as string);
    const delegate = profileMap.get(r.delegate_user_id as string);
    return {
      id: r.id as string,
      tenant_id: r.tenant_id as string,
      delegator_user_id: r.delegator_user_id as string,
      delegate_user_id: r.delegate_user_id as string,
      form_id: (r.form_id as string | null) ?? null,
      amount_limit: (r.amount_limit as number | null) ?? null,
      effective_from: r.effective_from as string,
      effective_to: (r.effective_to as string | null) ?? null,
      created_at: r.created_at as string,
      updated_at: r.updated_at as string,
      created_by: r.created_by as string,
      delegator: {
        display_name: delegator?.display_name ?? '(알 수 없음)',
        email: delegator?.email ?? ''
      },
      delegate: {
        display_name: delegate?.display_name ?? '(알 수 없음)',
        email: delegate?.email ?? ''
      },
      form: r.form_id ? formMap.get(r.form_id as string) ?? null : null
    };
  });
}

export async function fetchDelegationRule(
  supabase: SupabaseClient,
  tenantId: string,
  id: string
): Promise<DelegationRuleListItem | null> {
  const { data: row } = await supabase
    .from('delegation_rules')
    .select(
      'id, tenant_id, delegator_user_id, delegate_user_id, form_id, amount_limit, effective_from, effective_to, created_at, updated_at, created_by'
    )
    .eq('tenant_id', tenantId)
    .eq('id', id)
    .maybeSingle();

  if (!row) return null;

  const profileMap = await fetchProfilesByIds(supabase, [
    row.delegator_user_id as string,
    row.delegate_user_id as string
  ]);

  let form: { id: string; code: string; name: string } | null = null;
  if (row.form_id) {
    const { data: f } = await supabase
      .from('approval_forms')
      .select('id, code, name')
      .eq('id', row.form_id as string)
      .maybeSingle();
    if (f) {
      form = {
        id: f.id as string,
        code: f.code as string,
        name: f.name as string
      };
    }
  }

  const delegator = profileMap.get(row.delegator_user_id as string);
  const delegate = profileMap.get(row.delegate_user_id as string);

  return {
    id: row.id as string,
    tenant_id: row.tenant_id as string,
    delegator_user_id: row.delegator_user_id as string,
    delegate_user_id: row.delegate_user_id as string,
    form_id: (row.form_id as string | null) ?? null,
    amount_limit: (row.amount_limit as number | null) ?? null,
    effective_from: row.effective_from as string,
    effective_to: (row.effective_to as string | null) ?? null,
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
    created_by: row.created_by as string,
    delegator: {
      display_name: delegator?.display_name ?? '(알 수 없음)',
      email: delegator?.email ?? ''
    },
    delegate: {
      display_name: delegate?.display_name ?? '(알 수 없음)',
      email: delegate?.email ?? ''
    },
    form
  };
}
