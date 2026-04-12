import { error, fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type {
  FormSchema,
  DocumentStatus,
  StepStatus,
  StepType,
  AuditAction,
  ApprovalLineItem
} from '$lib/types/approval';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import { fetchActiveProxyFor } from '$lib/server/queries/absences';
import { createDownloadUrls } from '$lib/server/downloadUrl';
import type { SupabaseClient } from '@supabase/supabase-js';

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

  const userId = locals.user!.id;

  // 1. document
  const { data: doc, error: docErr } = await locals.supabase
    .from('approval_documents')
    .select(
      'id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, completed_at, created_at, updated_at'
    )
    .eq('id', params.id)
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  if (docErr || !doc) error(404, '문서를 찾을 수 없습니다');

  // 2. form (for name/code)
  const { data: form } = await locals.supabase
    .from('approval_forms')
    .select('name, code')
    .eq('id', doc.form_id as string)
    .maybeSingle();

  // 3. steps
  const { data: stepRows } = await locals.supabase
    .from('approval_steps')
    .select('id, step_index, step_type, approver_user_id, status, acted_at, comment, acted_by_proxy_user_id')
    .eq('document_id', doc.id as string)
    .order('step_index', { ascending: true });

  // 4. attachments
  const { data: attachmentRows } = await locals.supabase
    .from('approval_attachments')
    .select('id, storage_path, file_name, mime, size, uploaded_by')
    .eq('document_id', doc.id as string)
    .order('uploaded_at', { ascending: true });

  // 5. audit logs
  const { data: auditRows } = await locals.supabase
    .from('approval_audit_logs')
    .select('id, action, payload, actor_id, created_at')
    .eq('document_id', doc.id as string)
    .order('created_at', { ascending: true });

  // 6. resolve all profile ids (drafter + approvers + audit actors)
  const allUserIds: string[] = [
    doc.drafter_id as string,
    ...((stepRows ?? []).map((s) => s.approver_user_id as string)),
    ...((auditRows ?? []).map((a) => a.actor_id as string))
  ];
  const profileMap = await fetchProfilesByIds(locals.supabase, allUserIds);

  // 7. download urls for attachments
  const downloadUrls = await createDownloadUrls(
    locals.supabase,
    (attachmentRows ?? []).map((a) => ({
      storage_path: a.storage_path as string,
      file_name: a.file_name as string
    }))
  );

  // 8. authorization flags
  const status = doc.status as DocumentStatus;
  const currentStepIndex = doc.current_step_index as number;
  const currentStep = (stepRows ?? []).find(
    (s) => (s.step_index as number) === currentStepIndex
  );

  // v1.1 M12: 현재 사용자가 대리할 수 있는 원 approver 목록
  const activeProxyFor = await fetchActiveProxyFor(
    locals.supabase,
    currentTenant.id,
    userId,
    doc.form_id as string
  );

  // v1.1 M13: pending_post_facto 도 actionable
  const isActionableStatus = status === 'in_progress' || status === 'pending_post_facto';
  const isCurrentStepActionable =
    isActionableStatus &&
    (currentStep?.status as StepStatus) === 'pending' &&
    (currentStep?.step_type as StepType) === 'approval';

  const isOwnApproval = isCurrentStepActionable && currentStep?.approver_user_id === userId;
  const isProxyApproval =
    isCurrentStepActionable &&
    currentStep?.approver_user_id !== userId &&
    activeProxyFor.has(currentStep?.approver_user_id as string);

  const canApprove = isOwnApproval || isProxyApproval;

  const canWithdraw = isActionableStatus && doc.drafter_id === userId;

  // 누구든 문서를 볼 수 있으면 코멘트 가능 (RLS가 이미 보장)
  const canComment = true;

  // 9. build response shape
  const drafter = profileMap.get(doc.drafter_id as string);

  const steps = (stepRows ?? []).map((s) => {
    const p = profileMap.get(s.approver_user_id as string);
    return {
      id: s.id as string,
      step_index: s.step_index as number,
      step_type: s.step_type as StepType,
      approver_user_id: s.approver_user_id as string,
      approver_name: p?.display_name ?? '(알 수 없음)',
      approver_email: p?.email ?? '',
      status: s.status as StepStatus,
      acted_at: (s.acted_at as string | null) ?? null,
      comment: (s.comment as string | null) ?? null,
      acted_by_proxy_user_id: (s.acted_by_proxy_user_id as string | null) ?? null
    };
  });

  const audits = (auditRows ?? []).map((a) => {
    const p = profileMap.get(a.actor_id as string);
    return {
      id: a.id as string,
      action: a.action as AuditAction,
      payload: (a.payload as Record<string, unknown>) ?? {},
      created_at: a.created_at as string,
      actorName: p?.display_name ?? '(알 수 없음)',
      actorEmail: p?.email ?? ''
    };
  });

  // ApprovalLine 컴포넌트가 expected하는 line 형태
  const approvalLineReadonly: ApprovalLineItem[] = steps.map((s) => ({
    userId: s.approver_user_id,
    stepType: s.step_type
  }));

  return {
    document: {
      id: doc.id as string,
      doc_number: doc.doc_number as string,
      status,
      form_id: doc.form_id as string,
      form_name: (form?.name as string) ?? '(양식 없음)',
      form_code: (form?.code as string) ?? '',
      form_schema_snapshot: doc.form_schema_snapshot as unknown as FormSchema,
      content: (doc.content as Record<string, unknown>) ?? {},
      drafter_id: doc.drafter_id as string,
      drafter_name: drafter?.display_name ?? '(알 수 없음)',
      drafter_email: drafter?.email ?? '',
      current_step_index: currentStepIndex,
      submitted_at: (doc.submitted_at as string | null) ?? null,
      completed_at: (doc.completed_at as string | null) ?? null
    },
    steps,
    attachments: (attachmentRows ?? []).map((a) => ({
      id: a.id as string,
      storage_path: a.storage_path as string,
      file_name: a.file_name as string,
      mime: a.mime as string,
      size: a.size as number
    })),
    downloadUrls,
    audits,
    approvalLineReadonly,
    canApprove,
    canWithdraw,
    canComment,
    isProxyApproval
  };
};

export const actions: Actions = {
  approve: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const commentRaw = fd.get('comment')?.toString() ?? '';
    const comment = commentRaw.trim() === '' ? null : commentRaw.trim();

    const { error: err } = await locals.supabase.rpc('fn_approve_step', {
      p_document_id: params.id,
      p_comment: comment
    });

    if (err) return fail(400, { actionError: err.message || '승인 실패' });
    return { ok: true };
  },

  reject: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const comment = (fd.get('comment')?.toString() ?? '').trim();
    if (!comment) return fail(400, { actionError: '반려 사유 필수' });

    const { error: err } = await locals.supabase.rpc('fn_reject_step', {
      p_document_id: params.id,
      p_comment: comment
    });

    if (err) return fail(400, { actionError: err.message || '반려 실패' });
    return { ok: true };
  },

  withdraw: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const reasonRaw = fd.get('reason')?.toString() ?? '';
    const reason = reasonRaw.trim() === '' ? null : reasonRaw.trim();

    const { error: err } = await locals.supabase.rpc('fn_withdraw_document', {
      p_document_id: params.id,
      p_reason: reason
    });

    if (err) return fail(400, { actionError: err.message || '회수 실패' });
    return { ok: true };
  },

  comment: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!currentTenant) return fail(404);

    const fd = await request.formData();
    const comment = (fd.get('comment')?.toString() ?? '').trim();
    if (!comment) return fail(400, { actionError: '코멘트 필수' });

    const { error: err } = await locals.supabase.rpc('fn_add_comment', {
      p_document_id: params.id,
      p_comment: comment
    });

    if (err) return fail(400, { actionError: err.message || '코멘트 실패' });
    return { ok: true };
  }
};
