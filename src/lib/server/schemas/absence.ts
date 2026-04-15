import { z } from 'zod';
import { ABSENCE_TYPES } from '$lib/absenceTypes';

// Re-export client-safe constants so server code can reference them from one place.
export { ABSENCE_TYPES, ABSENCE_TYPE_LABELS, type AbsenceType } from '$lib/absenceTypes';

/**
 * v1.1 M12: user_absences CRUD용 Zod schema.
 *
 * - user_id는 폼에서 입력 안 받음 (self-service는 auth.uid(), admin은 폼에서)
 * - user !== delegate 검증 (DB CHECK와 중복)
 * - end >= start 검증 (하루짜리 부재 허용)
 *
 * Form UI는 날짜만 받고(`<input type="date">`) 저장 시 KST 하루 경계
 * (00:00 ~ 23:59:59)로 확장한다. fn_approve_with_proxy의 absence 매칭은
 * `now() BETWEEN start_at AND end_at` 이라 종료일 당일 오후에도 유효해야 함.
 */

export const absenceSchema = z
  .object({
    user_id: z.string().uuid('사용자 선택이 필요합니다'),
    delegate_user_id: z.string().uuid('대리인 선택이 필요합니다'),
    absence_type: z.enum(ABSENCE_TYPES),
    scope_form_id: z.string().uuid().nullable(),
    start_at: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일이 필요합니다' }) }),
    end_at: z.coerce.date({ errorMap: () => ({ message: '유효한 종료일이 필요합니다' }) }),
    reason: z.string().max(500).nullable()
  })
  .refine((d) => d.user_id !== d.delegate_user_id, {
    message: '본인과 대리인은 달라야 합니다',
    path: ['delegate_user_id']
  })
  .refine((d) => d.end_at >= d.start_at, {
    message: '종료일은 시작일 이후여야 합니다',
    path: ['end_at']
  });

export type AbsenceInput = z.infer<typeof absenceSchema>;

/**
 * Self-service 용 schema — user_id 없음 (서버에서 auth.uid() 주입).
 */
export const selfAbsenceSchema = z
  .object({
    delegate_user_id: z.string().uuid('대리인 선택이 필요합니다'),
    absence_type: z.enum(ABSENCE_TYPES),
    scope_form_id: z.string().uuid().nullable(),
    start_at: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일이 필요합니다' }) }),
    end_at: z.coerce.date({ errorMap: () => ({ message: '유효한 종료일이 필요합니다' }) }),
    reason: z.string().max(500).nullable()
  })
  .refine((d) => d.end_at >= d.start_at, {
    message: '종료일은 시작일 이후여야 합니다',
    path: ['end_at']
  });

export type SelfAbsenceInput = z.infer<typeof selfAbsenceSchema>;

/**
 * 날짜 입력(YYYY-MM-DD)을 KST 하루 경계 ISO로 확장:
 * - start_at: `YYYY-MM-DDT00:00:00+09:00`
 * - end_at:   `YYYY-MM-DDT23:59:59+09:00`
 */
export function coerceAbsenceFormData(fd: FormData, opts: { includeUserId: boolean }): unknown {
  const scopeRaw = fd.get('scope_form_id')?.toString() ?? '';
  const reasonRaw = fd.get('reason')?.toString() ?? '';
  const startRaw = fd.get('start_at')?.toString() ?? '';
  const endRaw = fd.get('end_at')?.toString() ?? '';
  const base = {
    delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
    absence_type: fd.get('absence_type')?.toString() ?? 'other',
    scope_form_id: scopeRaw === '' ? null : scopeRaw,
    start_at: startRaw ? `${startRaw}T00:00:00+09:00` : '',
    end_at: endRaw ? `${endRaw}T23:59:59+09:00` : '',
    reason: reasonRaw === '' ? null : reasonRaw
  };
  if (opts.includeUserId) {
    return { ...base, user_id: fd.get('user_id')?.toString() ?? '' };
  }
  return base;
}
