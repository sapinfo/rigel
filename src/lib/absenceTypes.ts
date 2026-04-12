/**
 * v1.1 M12: Client-safe absence 상수.
 *
 * $lib/server/* 는 SvelteKit 서버 전용 — .svelte 에서 import 불가.
 * 브라우저에서 필요한 enum 값·라벨만 본 파일에 둔다.
 * $lib/server/schemas/absence.ts 가 여기서 re-import 하여 단일 진실점 유지.
 */

export const ABSENCE_TYPES = ['annual', 'sick', 'business_trip', 'other'] as const;

export type AbsenceType = (typeof ABSENCE_TYPES)[number];

export const ABSENCE_TYPE_LABELS: Record<AbsenceType, string> = {
  annual: '연차',
  sick: '병가',
  business_trip: '출장',
  other: '기타'
};
