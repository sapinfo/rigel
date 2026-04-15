import { z } from 'zod';

export const approvalLineItemSchema = z.object({
  userId: z.string().uuid(),
  // v2.2: agreement(합의) 추가. DB step_type enum 은 이미 확장됨 (0052/0055).
  // fn_agree_step / fn_disagree_step 으로 처리. UI 에서 ApproverPicker 로 선택 가능.
  stepType: z.enum(['approval', 'agreement', 'reference']),
  // v1.2: 병렬 그룹 pointer. 미지정 시 순차 (index 기반 자동 할당).
  groupOrder: z.number().int().min(0).optional()
});

export const approvalLineSchema = z
  .array(approvalLineItemSchema)
  .min(1, '결재선은 최소 1명 이상')
  .refine(
    (line) => line.some((i) => i.stepType === 'approval'),
    '승인 단계가 최소 1개 필요'
  )
  .refine((line) => {
    const ids = line.map((i) => i.userId);
    return new Set(ids).size === ids.length;
  }, '결재자 중복 불가')
  // v1.2: groupOrder 검증 — 지정된 경우 연속성 (0, 1, ..., K-1)
  .refine(
    (line) => {
      const orders = line
        .map((i) => i.groupOrder)
        .filter((g): g is number => g !== undefined);
      if (orders.length === 0) return true; // 전부 미지정 = 순차
      if (orders.length !== line.length) return false; // 부분 지정 금지
      const set = new Set(orders);
      const max = Math.max(...orders);
      return set.size === max + 1 && Math.min(...orders) === 0;
    },
    'groupOrder 는 전부 지정하거나 전부 생략해야 하며, 0 부터 연속이어야 합니다'
  )
  .refine(
    (line) => {
      // 각 그룹에 최소 1개 approval step
      const orders = line.map((i, idx) => i.groupOrder ?? idx);
      const groupApprovals = new Map<number, number>();
      line.forEach((item, idx) => {
        const g = orders[idx];
        if (item.stepType === 'approval') {
          groupApprovals.set(g, (groupApprovals.get(g) ?? 0) + 1);
        }
      });
      // 모든 group 이 ≥ 1 approval 보유
      const allGroups = new Set(orders);
      for (const g of allGroups) {
        if ((groupApprovals.get(g) ?? 0) === 0) return false;
      }
      return true;
    },
    '각 그룹에 승인 단계가 최소 1개 필요합니다'
  );

export const submitDraftSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  approvalLine: approvalLineSchema,
  attachmentIds: z.array(z.string().uuid()).default([]),
  documentId: z.string().uuid().optional()
});

export const saveDraftSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  documentId: z.string().uuid().optional()
});

export const approveSchema = z.object({
  comment: z.string().trim().max(2000).nullable().optional()
});

export const rejectSchema = z.object({
  comment: z.string().trim().min(1, '반려 사유 필수').max(2000)
});

export const withdrawSchema = z.object({
  reason: z.string().trim().max(2000).optional()
});

export const commentSchema = z.object({
  comment: z.string().trim().min(1).max(2000)
});

export type ApprovalLineItem = z.infer<typeof approvalLineItemSchema>;
export type SubmitDraftInput = z.infer<typeof submitDraftSchema>;
