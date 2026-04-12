import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchProfilesByIds } from './profiles';
import type { AbsenceType } from '$lib/absenceTypes';

/**
 * v1.1 M12: user_absences 조회 helper. profiles.ts 패턴 재사용 (2-query join).
 */

export type AbsenceRow = {
  id: string;
  tenant_id: string;
  user_id: string;
  delegate_user_id: string;
  absence_type: AbsenceType;
  scope_form_id: string | null;
  start_at: string;
  end_at: string;
  reason: string | null;
  created_at: string;
  updated_at: string;
};

export type AbsenceListItem = AbsenceRow & {
  user: { display_name: string; email: string };
  delegate: { display_name: string; email: string };
  scope_form: { id: string; code: string; name: string } | null;
};

export async function fetchAbsences(
  supabase: SupabaseClient,
  tenantId: string,
  filter?: { userId?: string }
): Promise<AbsenceListItem[]> {
  let query = supabase
    .from('user_absences')
    .select(
      'id, tenant_id, user_id, delegate_user_id, absence_type, scope_form_id, start_at, end_at, reason, created_at, updated_at'
    )
    .eq('tenant_id', tenantId)
    .order('start_at', { ascending: false });

  if (filter?.userId) {
    query = query.eq('user_id', filter.userId);
  }

  const { data: rows } = await query;
  if (!rows || rows.length === 0) return [];

  const userIds = new Set<string>();
  const formIds = new Set<string>();
  for (const r of rows) {
    userIds.add(r.user_id as string);
    userIds.add(r.delegate_user_id as string);
    if (r.scope_form_id) formIds.add(r.scope_form_id as string);
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
    const user = profileMap.get(r.user_id as string);
    const delegate = profileMap.get(r.delegate_user_id as string);
    return {
      id: r.id as string,
      tenant_id: r.tenant_id as string,
      user_id: r.user_id as string,
      delegate_user_id: r.delegate_user_id as string,
      absence_type: r.absence_type as AbsenceType,
      scope_form_id: (r.scope_form_id as string | null) ?? null,
      start_at: r.start_at as string,
      end_at: r.end_at as string,
      reason: (r.reason as string | null) ?? null,
      created_at: r.created_at as string,
      updated_at: r.updated_at as string,
      user: {
        display_name: user?.display_name ?? '(알 수 없음)',
        email: user?.email ?? ''
      },
      delegate: {
        display_name: delegate?.display_name ?? '(알 수 없음)',
        email: delegate?.email ?? ''
      },
      scope_form: r.scope_form_id ? formMap.get(r.scope_form_id as string) ?? null : null
    };
  });
}

export async function fetchAbsence(
  supabase: SupabaseClient,
  tenantId: string,
  id: string
): Promise<AbsenceListItem | null> {
  const { data: row } = await supabase
    .from('user_absences')
    .select(
      'id, tenant_id, user_id, delegate_user_id, absence_type, scope_form_id, start_at, end_at, reason, created_at, updated_at'
    )
    .eq('tenant_id', tenantId)
    .eq('id', id)
    .maybeSingle();

  if (!row) return null;

  const profileMap = await fetchProfilesByIds(supabase, [
    row.user_id as string,
    row.delegate_user_id as string
  ]);

  let scope_form: { id: string; code: string; name: string } | null = null;
  if (row.scope_form_id) {
    const { data: f } = await supabase
      .from('approval_forms')
      .select('id, code, name')
      .eq('id', row.scope_form_id as string)
      .maybeSingle();
    if (f) {
      scope_form = {
        id: f.id as string,
        code: f.code as string,
        name: f.name as string
      };
    }
  }

  const user = profileMap.get(row.user_id as string);
  const delegate = profileMap.get(row.delegate_user_id as string);

  return {
    id: row.id as string,
    tenant_id: row.tenant_id as string,
    user_id: row.user_id as string,
    delegate_user_id: row.delegate_user_id as string,
    absence_type: row.absence_type as AbsenceType,
    scope_form_id: (row.scope_form_id as string | null) ?? null,
    start_at: row.start_at as string,
    end_at: row.end_at as string,
    reason: (row.reason as string | null) ?? null,
    created_at: row.created_at as string,
    updated_at: row.updated_at as string,
    user: {
      display_name: user?.display_name ?? '(알 수 없음)',
      email: user?.email ?? ''
    },
    delegate: {
      display_name: delegate?.display_name ?? '(알 수 없음)',
      email: delegate?.email ?? ''
    },
    scope_form
  };
}

/**
 * 현재 시점 기준으로 acting_user가 대리할 수 있는 원 approver user_id 목록.
 * /approval/documents/[id] 로드 시 "대리 승인" CTA 판단에 사용.
 */
export async function fetchActiveProxyFor(
  supabase: SupabaseClient,
  tenantId: string,
  delegateUserId: string,
  formId: string
): Promise<Set<string>> {
  const nowIso = new Date().toISOString();
  const { data } = await supabase
    .from('user_absences')
    .select('user_id, scope_form_id')
    .eq('tenant_id', tenantId)
    .eq('delegate_user_id', delegateUserId)
    .lte('start_at', nowIso)
    .gte('end_at', nowIso);

  const out = new Set<string>();
  for (const r of data ?? []) {
    const scope = r.scope_form_id as string | null;
    if (scope === null || scope === formId) {
      out.add(r.user_id as string);
    }
  }
  return out;
}
