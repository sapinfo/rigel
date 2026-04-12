import { z } from 'zod';

/**
 * v1.1 M11: delegation_rules CRUD용 Zod schema.
 *
 * - delegator/delegate는 서로 달라야 함 (DB CHECK와 중복 검증)
 * - form_id는 선택 (NULL = 전 양식)
 * - amount_limit은 선택 (NULL = 금액 무관). 0 이상.
 * - effective_from는 필수. effective_to는 선택 (NULL = 상시).
 * - effective_to > effective_from 검증 (DB CHECK와 중복)
 */
export const delegationRuleSchema = z
  .object({
    delegator_user_id: z.string().uuid('위임자 선택이 필요합니다'),
    delegate_user_id: z.string().uuid('대리 수행자 선택이 필요합니다'),
    form_id: z.string().uuid().nullable(),
    amount_limit: z.number().nonnegative('금액 한도는 0 이상이어야 합니다').nullable(),
    effective_from: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일시가 필요합니다' }) }),
    effective_to: z.coerce.date().nullable()
  })
  .refine((d) => d.delegator_user_id !== d.delegate_user_id, {
    message: '위임자와 대리 수행자는 달라야 합니다',
    path: ['delegate_user_id']
  })
  .refine((d) => !d.effective_to || d.effective_to > d.effective_from, {
    message: '종료일시는 시작일시 이후여야 합니다',
    path: ['effective_to']
  });

export type DelegationRuleInput = z.infer<typeof delegationRuleSchema>;

/**
 * Form payload → schema input 변환 유틸.
 * HTML form은 빈 문자열을 보내므로 nullable 필드를 명시적으로 null 처리.
 */
export function coerceDelegationRuleFormData(fd: FormData): unknown {
  const formIdRaw = fd.get('form_id')?.toString() ?? '';
  const amountRaw = fd.get('amount_limit')?.toString() ?? '';
  const effectiveToRaw = fd.get('effective_to')?.toString() ?? '';

  return {
    delegator_user_id: fd.get('delegator_user_id')?.toString() ?? '',
    delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
    form_id: formIdRaw === '' ? null : formIdRaw,
    amount_limit: amountRaw === '' ? null : Number(amountRaw),
    effective_from: fd.get('effective_from')?.toString() ?? '',
    effective_to: effectiveToRaw === '' ? null : effectiveToRaw
  };
}
