import { error, fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import {
  approvalLineSchema,
  type ApprovalLineItem
} from '$lib/server/schemas/approvalActions';
import { computeDocumentHash } from '$lib/hash/documentHash';
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

export const load: PageServerLoad = async ({ locals, params, parent, url }) => {
  const { currentTenant } = await parent();
  if (!currentTenant) error(404);

  // 임시저장 문서 불러오기
  const draftId = url.searchParams.get('draft');
  let draftContent: Record<string, unknown> | null = null;
  let loadedDocumentId: string | null = null;
  if (draftId) {
    const { data: draftDoc } = await locals.supabase
      .from('approval_documents')
      .select('id, content, status')
      .eq('id', draftId)
      .eq('tenant_id', currentTenant.id)
      .eq('drafter_id', locals.user!.id)
      .eq('status', 'draft')
      .maybeSingle();
    if (draftDoc) {
      draftContent = draftDoc.content as Record<string, unknown>;
      loadedDocumentId = draftDoc.id as string;
    }
  }

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
        .select('id, display_name, email, signature_storage_path, signature_sha256')
        .in('id', userIds)
    : {
        data: [] as {
          id: string;
          display_name: string;
          email: string;
          signature_storage_path: string | null;
          signature_sha256: string | null;
        }[]
      };

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
      jobTitle: (row.job_title as string | null) ?? null,
      signatureStoragePath: (p?.signature_storage_path as string | null | undefined) ?? null,
      signatureSha256: (p?.signature_sha256 as string | null | undefined) ?? null
    };
  });

  // v2.3 M2: 부서 (OrgTreePicker용)
  const { data: deptRows } = await locals.supabase
    .from('departments')
    .select('id, name, parent_id')
    .eq('tenant_id', currentTenant.id)
    .order('sort_order').order('name');

  // v2.2 M1: 즐겨찾기
  const { data: favRows } = await locals.supabase
    .from('approval_line_favorites')
    .select('id, name, form_id, line_json')
    .eq('tenant_id', currentTenant.id)
    .eq('user_id', locals.user!.id)
    .order('created_at', { ascending: false });

  // v2.2 M2: 템플릿 (이 양식 또는 전체)
  const { data: tplRows } = await locals.supabase
    .from('approval_line_templates')
    .select('id, name, form_id, line_json, is_default, priority')
    .eq('tenant_id', currentTenant.id)
    .or(`form_id.eq.${form.id},form_id.is.null`)
    .order('priority', { ascending: true });

  return {
    form: {
      id: form.id as string,
      code: form.code as string,
      name: form.name as string,
      description: (form.description as string | null) ?? null,
      schema: form.schema as unknown as FormSchema,
      defaultApprovalLine: (form.default_approval_line as unknown as ApprovalLineItem[]) ?? []
    },
    members,
    draftContent,
    loadedDocumentId,
    departments: (deptRows ?? []).map((d) => ({ id: d.id as string, name: d.name as string, parentId: (d.parent_id as string | null) ?? null })),
    favorites: (favRows ?? []).map((f) => ({
      id: f.id as string,
      name: f.name as string,
      formId: (f.form_id as string | null) ?? null,
      lineJson: f.line_json as unknown as ApprovalLineItem[]
    })),
    templates: (tplRows ?? []).map((t) => ({
      id: t.id as string,
      name: t.name as string,
      lineJson: t.line_json as unknown as ApprovalLineItem[],
      isDefault: t.is_default as boolean
    }))
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

    // v1.2 M16b: content_hash 계산.
    // form snapshot, attachment sha256 을 서버에서 조회하여 해시 입력 구성.
    const { data: formRow, error: formErr } = await locals.supabase
      .from('approval_forms')
      .select('schema')
      .eq('id', parsed.data.formId)
      .eq('is_published', true)
      .maybeSingle();

    if (formErr || !formRow) {
      return fail(400, { errors: formError('양식 조회 실패') });
    }

    let attachmentSha256s: string[] = [];
    if (parsed.data.attachmentIds.length > 0) {
      const { data: attRows, error: attErr } = await locals.supabase
        .from('approval_attachments')
        .select('sha256')
        .in('id', parsed.data.attachmentIds);

      if (attErr || !attRows) {
        return fail(400, { errors: formError('첨부 조회 실패') });
      }
      const hashes = attRows
        .map((a) => a.sha256 as string | null)
        .filter((h): h is string => h !== null);
      if (hashes.length !== attRows.length) {
        return fail(400, {
          errors: formError('첨부 파일 해시 누락 — 재업로드 후 다시 시도해주세요')
        });
      }
      attachmentSha256s = hashes;
    }

    const contentHash = await computeDocumentHash({
      formSchema: formRow.schema as unknown as FormSchema,
      content: parsed.data.content,
      approvalLine: parsed.data.approvalLine,
      attachmentSha256s
    });

    const { data: doc, error: rpcErr } = await locals.supabase
      .rpc('fn_submit_draft', {
        p_tenant_id: currentTenant.id,
        p_form_id: parsed.data.formId,
        p_content: parsed.data.content,
        p_approval_line: parsed.data.approvalLine,
        p_content_hash: contentHash,
        p_attachment_ids: parsed.data.attachmentIds,
        p_document_id: parsed.data.documentId ?? undefined
      })
      .single();

    if (rpcErr) {
      return fail(400, { errors: formError(rpcErr.message || '상신 실패') });
    }

    // v2.2 M7 + v2.3 M4: 메타데이터 저장
    const urgency = fd.get('urgency')?.toString() ?? '일반';
    const retentionPeriod = fd.get('retentionPeriod')?.toString() ?? '5년';
    const securityLevel = fd.get('securityLevel')?.toString() ?? '일반';
    if (doc && (urgency !== '일반' || retentionPeriod !== '5년' || securityLevel !== '일반')) {
      const docId = (doc as unknown as { id: string }).id;
      await locals.supabase
        .from('approval_documents')
        .update({ urgency, retention_period: retentionPeriod, security_level: securityLevel })
        .eq('id', docId);
    }

    redirect(303, `/t/${currentTenant.slug}/approval/inbox`);
  },

  // v2.2 M1: 즐겨찾기 저장
  saveFavorite: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const name = fd.get('favName')?.toString()?.trim();
    const lineJsonRaw = fd.get('lineJson')?.toString();
    const formId = fd.get('formId')?.toString() || null;
    if (!name || !lineJsonRaw) return fail(400, { errors: formError('이름과 결재선이 필요합니다') });

    let lineJson;
    try { lineJson = JSON.parse(lineJsonRaw); } catch { return fail(400); }

    const { error: err } = await locals.supabase
      .from('approval_line_favorites')
      .insert({ tenant_id: currentTenant.id, user_id: locals.user.id, name, form_id: formId, line_json: lineJson });

    if (err) return fail(500, { errors: formError(err.message) });
    return { favSaved: true };
  },

  // v2.2 M1: 즐겨찾기 삭제
  removeFavorite: async ({ request, locals }) => {
    if (!locals.user) return fail(401);
    const fd = await request.formData();
    const id = fd.get('favId')?.toString();
    if (!id) return fail(400);

    await locals.supabase.from('approval_line_favorites').delete().eq('id', id).eq('user_id', locals.user.id);
    return { favRemoved: true };
  },

  // v2.1 M2: 결재선 자동 구성 프리뷰
  resolvePreview: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const formId = fd.get('formId')?.toString();
    const content = parseJson(fd.get('content'), {} as Record<string, unknown>);
    if (!formId) return fail(400, { errors: formError('양식 ID 필수') });

    // 1. fn_resolve_approval_line RPC
    const { data: resolved, error: rpcErr } = await locals.supabase
      .rpc('fn_resolve_approval_line', {
        p_tenant_id: currentTenant.id,
        p_form_id: formId,
        p_content: content
      });

    if (rpcErr) {
      return { preview: { approvers: [], ruleName: null, error: rpcErr.message } };
    }

    const lineItems = (resolved ?? []) as { userId: string; stepType: string }[];
    if (lineItems.length === 0) {
      return { preview: { approvers: [], ruleName: null, error: '매칭되는 결재선 규칙이 없습니다. 관리자에게 문의하세요.' } };
    }

    // 2. Profile + dept + jobTitle join
    const userIds = lineItems.map((i) => i.userId);

    const [profilesRes, tmRes, deptsRes, jtsRes] = await Promise.all([
      locals.supabase.from('profiles').select('id, display_name, email').in('id', userIds),
      locals.supabase.from('tenant_members').select('user_id, department_id, job_title_id').eq('tenant_id', currentTenant.id).in('user_id', userIds),
      locals.supabase.from('departments').select('id, name').eq('tenant_id', currentTenant.id),
      locals.supabase.from('job_titles').select('id, name').eq('tenant_id', currentTenant.id)
    ]);

    const profileMap = new Map((profilesRes.data ?? []).map((p) => [p.id as string, p]));
    const tmMap = new Map((tmRes.data ?? []).map((r) => [r.user_id as string, r]));
    const deptMap = new Map((deptsRes.data ?? []).map((d) => [d.id as string, d.name as string]));
    const jtMap = new Map((jtsRes.data ?? []).map((j) => [j.id as string, j.name as string]));

    const approvers = lineItems.map((item) => {
      const p = profileMap.get(item.userId);
      const tm = tmMap.get(item.userId);
      return {
        userId: item.userId,
        displayName: (p?.display_name as string) ?? '(알 수 없음)',
        email: (p?.email as string) ?? '',
        departmentName: tm?.department_id ? (deptMap.get(tm.department_id as string) ?? null) : null,
        jobTitleName: tm?.job_title_id ? (jtMap.get(tm.job_title_id as string) ?? null) : null,
        stepType: item.stepType
      };
    });

    // 3. 매칭 규칙 이름
    const { data: matchedRule } = await locals.supabase
      .from('approval_rules')
      .select('name')
      .eq('tenant_id', currentTenant.id)
      .eq('is_active', true)
      .or(`form_id.eq.${formId},form_id.is.null`)
      .order('priority', { ascending: true })
      .limit(1)
      .maybeSingle();

    return {
      preview: {
        approvers,
        ruleName: matchedRule?.name ?? null,
        error: null
      }
    };
  },

  // v1.1 M13: 후결 상신 (v1.2 M16b: content_hash 추가)
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

    // v1.2 M16b: content_hash 계산 (submit 과 동일 path)
    const { data: formRow, error: formErr } = await locals.supabase
      .from('approval_forms')
      .select('schema')
      .eq('id', parsed.data.formId)
      .eq('is_published', true)
      .maybeSingle();

    if (formErr || !formRow) {
      return fail(400, { errors: formError('양식 조회 실패') });
    }

    let attachmentSha256s: string[] = [];
    if (parsed.data.attachmentIds.length > 0) {
      const { data: attRows, error: attErr } = await locals.supabase
        .from('approval_attachments')
        .select('sha256')
        .in('id', parsed.data.attachmentIds);

      if (attErr || !attRows) {
        return fail(400, { errors: formError('첨부 조회 실패') });
      }
      const hashes = attRows
        .map((a) => a.sha256 as string | null)
        .filter((h): h is string => h !== null);
      if (hashes.length !== attRows.length) {
        return fail(400, {
          errors: formError('첨부 파일 해시 누락 — 재업로드 후 다시 시도해주세요')
        });
      }
      attachmentSha256s = hashes;
    }

    const contentHash = await computeDocumentHash({
      formSchema: formRow.schema as unknown as FormSchema,
      content: parsed.data.content,
      approvalLine: parsed.data.approvalLine,
      attachmentSha256s
    });

    const { data: doc, error: rpcErr } = await locals.supabase
      .rpc('fn_submit_post_facto', {
        p_tenant_id: currentTenant.id,
        p_form_id: parsed.data.formId,
        p_content: parsed.data.content,
        p_approval_line: parsed.data.approvalLine,
        p_content_hash: contentHash,
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
