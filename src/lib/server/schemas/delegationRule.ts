import { z } from 'zod';

/**
 * v1.1 M11: delegation_rules CRUD용 Zod schema.
 *
 * - delegator/delegate는 서로 달라야 함 (DB CHECK와 중복 검증)
 * - form_id는 선택 (NULL = 전 양식)
 * - amount_limit은 선택 (NULL = 금액 무관). 0 이상.
 * - effective_from는 필수. effective_to는 선택 (NULL = 상시).
 * - effective_to >= effective_from 검증 (같은 날 하루짜리 허용)
 *
 * Form UI는 날짜만 받고(HTML `<input type="date">`) 저장 시 KST 하루 경계
 * (00:00~23:59:59)로 확장한다. fn_submit_draft 는 `effective_from <= now()
 * AND effective_to >= now()` 로 매칭하므로 하루 종일 유효해야 함.
 */
export const delegationRuleSchema = z
  .object({
    delegator_user_id: z.string().uuid('위임자 선택이 필요합니다'),
    delegate_user_id: z.string().uuid('대리 수행자 선택이 필요합니다'),
    form_id: z.string().uuid().nullable(),
    amount_limit: z.number().nonnegative('금액 한도는 0 이상이어야 합니다').nullable(),
    effective_from: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일이 필요합니다' }) }),
    effective_to: z.coerce.date().nullable()
  })
  .refine((d) => d.delegator_user_id !== d.delegate_user_id, {
    message: '위임자와 대리 수행자는 달라야 합니다',
    path: ['delegate_user_id']
  })
  .refine((d) => !d.effective_to || d.effective_to >= d.effective_from, {
    message: '종료일은 시작일 이후여야 합니다',
    path: ['effective_to']
  });

export type DelegationRuleInput = z.infer<typeof delegationRuleSchema>;

/**
 * Form payload → schema input 변환 유틸.
 *
 * 날짜 입력(YYYY-MM-DD)을 KST 하루 경계 ISO 문자열로 확장:
 * - effective_from: `YYYY-MM-DDT00:00:00+09:00`
 * - effective_to:   `YYYY-MM-DDT23:59:59+09:00`
 *
 * 이러면 종료일 당일 오후 3시에도 `effective_to >= now()` 가 true 라 규칙이
 * 유효한 상태로 유지된다.
 */
export function coerceDelegationRuleFormData(fd: FormData): unknown {
  const formIdRaw = fd.get('form_id')?.toString() ?? '';
  const amountRaw = fd.get('amount_limit')?.toString() ?? '';
  const effectiveFromRaw = fd.get('effective_from')?.toString() ?? '';
  const effectiveToRaw = fd.get('effective_to')?.toString() ?? '';

  const fromIso = effectiveFromRaw ? `${effectiveFromRaw}T00:00:00+09:00` : '';
  const toIso = effectiveToRaw ? `${effectiveToRaw}T23:59:59+09:00` : null;

  return {
    delegator_user_id: fd.get('delegator_user_id')?.toString() ?? '',
    delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
    form_id: formIdRaw === '' ? null : formIdRaw,
    amount_limit: amountRaw === '' ? null : Number(amountRaw),
    effective_from: fromIso,
    effective_to: toIso
  };
}
