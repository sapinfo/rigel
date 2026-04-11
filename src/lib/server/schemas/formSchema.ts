import { z } from 'zod';

/**
 * Zod schema for validating an approval form's JSONB schema.
 * Loose discriminator-free validation — accepts any `version: 1` with a
 * `fields` array of well-formed objects. Unknown field types are allowed
 * (renderer will show a fallback).
 */

const fieldBase = z.object({
  id: z.string().regex(/^[a-z][a-z0-9_]*$/, '필드 ID는 snake_case'),
  type: z.string().min(1),
  label: z.string().min(1),
  required: z.boolean().optional(),
  help: z.string().optional(),
  placeholder: z.string().optional(),
  maxLength: z.number().int().positive().optional(),
  min: z.number().optional(),
  max: z.number().optional(),
  step: z.number().positive().optional(),
  unit: z.string().optional(),
  options: z
    .array(z.object({ value: z.string(), label: z.string() }))
    .optional(),
  multiple: z.boolean().optional(),
  maxFiles: z.number().int().positive().optional(),
  maxSizeBytes: z.number().int().positive().optional(),
  accept: z.string().optional()
});

export const formSchemaSchema = z.object({
  version: z.literal(1),
  fields: z
    .array(fieldBase)
    .min(1, '최소 1개 필드 필요')
    .refine((fields) => {
      const ids = fields.map((f) => f.id);
      return new Set(ids).size === ids.length;
    }, '필드 ID 중복 불가')
});

export const formMetaSchema = z.object({
  code: z
    .string()
    .trim()
    .min(2)
    .max(50)
    .regex(/^[a-z0-9][a-z0-9-]*[a-z0-9]$/, '소문자·숫자·하이픈만'),
  name: z.string().trim().min(1).max(100),
  description: z.string().trim().max(500).nullable().optional(),
  schema: z.unknown().transform((v, ctx) => {
    const parsed = formSchemaSchema.safeParse(v);
    if (!parsed.success) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: '양식 스키마 형식 오류: ' + parsed.error.issues[0]?.message
      });
      return z.NEVER;
    }
    return parsed.data;
  }),
  is_published: z.boolean().default(false)
});
