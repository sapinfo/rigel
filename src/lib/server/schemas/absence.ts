import { z } from 'zod';
import { ABSENCE_TYPES } from '$lib/absenceTypes';

// Re-export client-safe constants so server code can reference them from one place.
export { ABSENCE_TYPES, ABSENCE_TYPE_LABELS, type AbsenceType } from '$lib/absenceTypes';

/**
 * v1.1 M12: user_absences CRUD용 Zod schema.
 *
 * - user_id는 폼에서 입력 안 받음 (self-service는 auth.uid(), admin은 폼에서)
 * - user !== delegate 검증 (DB CHECK와 중복)
 * - end > start 검증 (DB CHECK와 중복)
 */

export const absenceSchema = z
  .object({
    user_id: z.string().uuid('사용자 선택이 필요합니다'),
    delegate_user_id: z.string().uuid('대리인 선택이 필요합니다'),
    absence_type: z.enum(ABSENCE_TYPES),
    scope_form_id: z.string().uuid().nullable(),
    start_at: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일시가 필요합니다' }) }),
    end_at: z.coerce.date({ errorMap: () => ({ message: '유효한 종료일시가 필요합니다' }) }),
    reason: z.string().max(500).nullable()
  })
  .refine((d) => d.user_id !== d.delegate_user_id, {
    message: '본인과 대리인은 달라야 합니다',
    path: ['delegate_user_id']
  })
  .refine((d) => d.end_at > d.start_at, {
    message: '종료일시는 시작일시 이후여야 합니다',
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
    start_at: z.coerce.date({ errorMap: () => ({ message: '유효한 시작일시가 필요합니다' }) }),
    end_at: z.coerce.date({ errorMap: () => ({ message: '유효한 종료일시가 필요합니다' }) }),
    reason: z.string().max(500).nullable()
  })
  .refine((d) => d.end_at > d.start_at, {
    message: '종료일시는 시작일시 이후여야 합니다',
    path: ['end_at']
  });

export type SelfAbsenceInput = z.infer<typeof selfAbsenceSchema>;

export function coerceAbsenceFormData(fd: FormData, opts: { includeUserId: boolean }): unknown {
  const scopeRaw = fd.get('scope_form_id')?.toString() ?? '';
  const reasonRaw = fd.get('reason')?.toString() ?? '';
  const base = {
    delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
    absence_type: fd.get('absence_type')?.toString() ?? 'other',
    scope_form_id: scopeRaw === '' ? null : scopeRaw,
    start_at: fd.get('start_at')?.toString() ?? '',
    end_at: fd.get('end_at')?.toString() ?? '',
    reason: reasonRaw === '' ? null : reasonRaw
  };
  if (opts.includeUserId) {
    return { ...base, user_id: fd.get('user_id')?.toString() ?? '' };
  }
  return base;
}
