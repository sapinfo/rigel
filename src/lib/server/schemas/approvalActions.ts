import { z } from 'zod';

export const approvalLineItemSchema = z.object({
  userId: z.string().uuid(),
  stepType: z.enum(['approval', 'reference'])
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
  }, '결재자 중복 불가');

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
