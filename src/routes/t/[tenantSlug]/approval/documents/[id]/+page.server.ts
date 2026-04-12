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

  // 3. steps (v1.2: group_order 포함)
  const { data: stepRows } = await locals.supabase
    .from('approval_steps')
    .select('id, step_index, group_order, step_type, approver_user_id, status, acted_at, comment, acted_by_proxy_user_id')
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

  // v1.2: approver 의 signature_storage_path 조회 + signed URL 생성 (60s TTL)
  const approverIds = Array.from(
    new Set((stepRows ?? []).map((s) => s.approver_user_id as string))
  );
  const signedSigUrls = new Map<string, string>();
  if (approverIds.length > 0) {
    const { data: sigProfiles } = await locals.supabase
      .from('profiles')
      .select('id, signature_storage_path')
      .in('id', approverIds);

    for (const p of sigProfiles ?? []) {
      const path = p.signature_storage_path as string | null;
      if (!path) continue;
      const { data: signed } = await locals.supabase.storage
        .from('user-signatures')
        .createSignedUrl(path, 60);
      if (signed?.signedUrl) {
        signedSigUrls.set(p.id as string, signed.signedUrl);
      }
    }
  }

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
      group_order: s.group_order as number,
      step_type: s.step_type as StepType,
      approver_user_id: s.approver_user_id as string,
      approver_name: p?.display_name ?? '(알 수 없음)',
      approver_email: p?.email ?? '',
      status: s.status as StepStatus,
      acted_at: (s.acted_at as string | null) ?? null,
      comment: (s.comment as string | null) ?? null,
      acted_by_proxy_user_id: (s.acted_by_proxy_user_id as string | null) ?? null,
      signature_url: signedSigUrls.get(s.approver_user_id as string) ?? null
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
  },

  // v2.2 M5: 재기안
  resubmit: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!currentTenant) return fail(404);

    // 기존 문서 조회 (rejected 상태 확인)
    const { data: doc } = await locals.supabase
      .from('approval_documents')
      .select('id, form_id, content, status, drafter_id')
      .eq('id', params.id)
      .eq('tenant_id', currentTenant.id)
      .single();

    if (!doc || doc.status !== 'rejected') return fail(400, { actionError: '반려된 문서만 재기안할 수 있습니다' });
    if (doc.drafter_id !== locals.user.id) return fail(403, { actionError: '본인이 기안한 문서만 재기안할 수 있습니다' });

    // 새 draft 생성
    const { data: newDoc, error: err } = await locals.supabase
      .rpc('fn_save_draft', {
        p_tenant_id: currentTenant.id,
        p_form_id: doc.form_id,
        p_content: doc.content
      })
      .single();

    if (err) return fail(400, { actionError: err.message || '재기안 실패' });

    const newId = (newDoc as unknown as { id: string }).id;
    // 양식 코드 조회
    const { data: formRow } = await locals.supabase
      .from('approval_forms')
      .select('code')
      .eq('id', doc.form_id as string)
      .single();

    const code = (formRow?.code as string) ?? 'general';
    return { resubmitRedirect: `/t/${currentTenant.slug}/approval/drafts/new/${code}` };
  },

  // v2.2 M6: 결재 독촉
  remind: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
    if (!currentTenant) return fail(404);

    // 문서 조회 + 현재 결재자 확인
    const { data: doc } = await locals.supabase
      .from('approval_documents')
      .select('id, status, drafter_id, current_step_index')
      .eq('id', params.id)
      .eq('tenant_id', currentTenant.id)
      .single();

    if (!doc || !['in_progress', 'pending_post_facto'].includes(doc.status as string))
      return fail(400, { actionError: '진행 중인 문서만 독촉할 수 있습니다' });
    if (doc.drafter_id !== locals.user.id)
      return fail(403, { actionError: '본인이 기안한 문서만 독촉할 수 있습니다' });

    // 현재 결재자 조회
    const { data: step } = await locals.supabase
      .from('approval_steps')
      .select('approver_user_id')
      .eq('document_id', doc.id)
      .eq('step_index', doc.current_step_index)
      .eq('status', 'pending')
      .limit(1)
      .maybeSingle();

    if (!step) return fail(400, { actionError: '현재 결재자를 찾을 수 없습니다' });

    // 알림 생성 (v1.3 notifications 테이블 재사용)
    await locals.supabase.from('notifications').insert({
      tenant_id: currentTenant.id,
      user_id: step.approver_user_id,
      document_id: doc.id,
      type: 'approval_requested',
      title: '결재 독촉',
      body: '기안자가 결재를 요청합니다. 확인해주세요.'
    });

    return { reminded: true };
  }
};
