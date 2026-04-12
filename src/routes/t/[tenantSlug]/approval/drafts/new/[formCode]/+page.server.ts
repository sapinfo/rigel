import { error, fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import {
  approvalLineSchema,
  type ApprovalLineItem
} from '$lib/server/schemas/approvalActions';
import type { Actions, PageServerLoad } from './$types';
import type { FormSchema, ProfileLite } from '$lib/types/approval';
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Actions don't trigger +layout.server.ts load, so locals.currentTenant is null.
 * Resolve tenant directly from slug + membership check.
 */
async function resolveTenant(
  supabase: SupabaseClient,
  userId: string,
  slug: string
): Promise<{ id: string; slug: string } | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('tenant:tenants!inner(id, slug)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  const t = data.tenant as unknown as { id: string; slug: string };
  return { id: t.id, slug: t.slug };
}

export const load: PageServerLoad = async ({ locals, params, parent }) => {
  const { currentTenant } = await parent();
  if (!currentTenant) error(404);

  // 1. 양식 조회 — 테넌트 양식 우선, 없으면 시스템 양식 fallback
  //    (fn_copy_system_forms가 보통 복사해둠, 시스템 양식 직접 사용은 예외적)
  const { data: forms, error: formErr } = await locals.supabase
    .from('approval_forms')
    .select('id, code, name, description, schema, default_approval_line, is_published, tenant_id')
    .eq('code', params.formCode)
    .eq('is_published', true)
    .or(`tenant_id.eq.${currentTenant.id},tenant_id.is.null`)
    .order('tenant_id', { ascending: false, nullsFirst: false })
    .limit(1);

  if (formErr || !forms || forms.length === 0) {
    error(404, `양식을 찾을 수 없습니다: ${params.formCode}`);
  }

  const form = forms[0];

  // 2. 테넌트 멤버 목록 (ApproverPicker용)
  // tenant_members.user_id → auth.users, profiles.id → auth.users.
  // 둘 사이 직접 FK 없어서 PostgREST embed 불가. 2-step query로 join.
  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, job_title, department_id')
    .eq('tenant_id', currentTenant.id);

  const userIds = (memberRows ?? []).map((r) => r.user_id as string);
  const { data: profileRows } = userIds.length
    ? await locals.supabase
        .from('profiles')
        .select('id, display_name, email')
        .in('id', userIds)
    : { data: [] as { id: string; display_name: string; email: string }[] };

  const profileMap = new Map(
    (profileRows ?? []).map((p) => [p.id as string, p])
  );

  const members: ProfileLite[] = (memberRows ?? []).map((row) => {
    const p = profileMap.get(row.user_id as string);
    return {
      id: (row.user_id as string),
      displayName: (p?.display_name as string | undefined) ?? '(알 수 없음)',
      email: (p?.email as string | undefined) ?? '',
      departmentId: (row.department_id as string | null) ?? null,
      jobTitle: (row.job_title as string | null) ?? null
    };
  });

  return {
    form: {
      id: form.id as string,
      code: form.code as string,
      name: form.name as string,
      description: (form.description as string | null) ?? null,
      schema: form.schema as unknown as FormSchema,
      defaultApprovalLine: (form.default_approval_line as unknown as ApprovalLineItem[]) ?? []
    },
    members
  };
};

// ─── Body schemas for actions ─────────────────────
// Parse the JSON fields from form data before running through the Zod schemas above.

function parseJson<T>(raw: FormDataEntryValue | null, fallback: T): T {
  if (raw == null) return fallback;
  try {
    return JSON.parse(raw.toString()) as T;
  } catch {
    return fallback;
  }
}

const saveDraftFormSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  documentId: z.string().uuid().optional().nullable()
});

const submitDraftFormSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  approvalLine: approvalLineSchema,
  attachmentIds: z.array(z.string().uuid()).default([]),
  documentId: z.string().uuid().optional().nullable()
});

// v1.1 M13: 후결 상신용 schema (문서 ID 없음 — 신규 기안만, reason 필수)
const submitPostFactoFormSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  approvalLine: approvalLineSchema,
  attachmentIds: z.array(z.string().uuid()).default([]),
  reason: z.string().trim().min(1, '후결 사유는 필수입니다').max(1000)
});

export const actions: Actions = {
  saveDraft: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const parsed = saveDraftFormSchema.safeParse({
      formId: fd.get('formId')?.toString(),
      content: parseJson(fd.get('content'), {} as Record<string, unknown>),
      documentId: fd.get('documentId')?.toString() || undefined
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed) });
    }

    const { data, error: rpcErr } = await locals.supabase
      .rpc('fn_save_draft', {
        p_tenant_id: currentTenant.id,
        p_form_id: parsed.data.formId,
        p_content: parsed.data.content,
        p_document_id: parsed.data.documentId ?? undefined
      })
      .single();

    if (rpcErr) {
      return fail(400, { errors: formError(rpcErr.message || '임시저장 실패') });
    }

    return {
      saved: true,
      documentId: (data as unknown as { id: string }).id
    };
  },

  submit: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const parsed = submitDraftFormSchema.safeParse({
      formId: fd.get('formId')?.toString(),
      content: parseJson(fd.get('content'), {} as Record<string, unknown>),
      approvalLine: parseJson(fd.get('approvalLine'), [] as unknown[]),
      attachmentIds: parseJson(fd.get('attachmentIds'), [] as string[]),
      documentId: fd.get('documentId')?.toString() || undefined
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed) });
    }

    const { data: doc, error: rpcErr } = await locals.supabase
      .rpc('fn_submit_draft', {
        p_tenant_id: currentTenant.id,
        p_form_id: parsed.data.formId,
        p_content: parsed.data.content,
        p_approval_line: parsed.data.approvalLine,
        p_attachment_ids: parsed.data.attachmentIds,
        p_document_id: parsed.data.documentId ?? undefined
      })
      .single();

    if (rpcErr) {
      return fail(400, { errors: formError(rpcErr.message || '상신 실패') });
    }

    // M6: 문서 상세 페이지는 M7. 당분간 결재함 placeholder로 리디렉트.
    redirect(303, `/t/${currentTenant.slug}/approval/inbox`);
  },

  // v1.1 M13: 후결 상신
  submitPostFacto: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const parsed = submitPostFactoFormSchema.safeParse({
      formId: fd.get('formId')?.toString(),
      content: parseJson(fd.get('content'), {} as Record<string, unknown>),
      approvalLine: parseJson(fd.get('approvalLine'), [] as unknown[]),
      attachmentIds: parseJson(fd.get('attachmentIds'), [] as string[]),
      reason: fd.get('reason')?.toString() ?? ''
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed) });
    }

    const { data: doc, error: rpcErr } = await locals.supabase
      .rpc('fn_submit_post_facto', {
        p_tenant_id: currentTenant.id,
        p_form_id: parsed.data.formId,
        p_content: parsed.data.content,
        p_approval_line: parsed.data.approvalLine,
        p_reason: parsed.data.reason,
        p_attachment_ids: parsed.data.attachmentIds
      })
      .single();

    if (rpcErr) {
      return fail(400, { errors: formError(rpcErr.message || '후결 상신 실패') });
    }

    redirect(303, `/t/${currentTenant.slug}/approval/inbox`);
  }
};
