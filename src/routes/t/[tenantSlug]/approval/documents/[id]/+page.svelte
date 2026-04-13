<script lang="ts">
  import { enhance } from '$app/forms';
  import DocumentHeader from '$lib/components/DocumentHeader.svelte';
  import StampLine from '$lib/components/StampLine.svelte';
  import FormRenderer from '$lib/components/FormRenderer.svelte';
  import ApprovalLine from '$lib/components/ApprovalLine.svelte';
  import DocumentSteps from '$lib/components/DocumentSteps.svelte';
  import AttachmentList from '$lib/components/AttachmentList.svelte';
  import AuditTimeline from '$lib/components/AuditTimeline.svelte';
  import ApprovalPanel from '$lib/components/ApprovalPanel.svelte';
  import type { ProfileLite } from '$lib/types/approval';
  import { page } from '$app/state';

  let { data, form } = $props();
  const printMode = $derived(page.url.searchParams.get('print') === '1');

  // ApprovalLine needs ProfileLite[] for display.
  // 이 뷰는 read-only 결재선 표시용이라 서명 메타는 DocumentSteps 에서 사용.
  const membersForLine = $derived<ProfileLite[]>(
    data.steps.map((s) => ({
      id: s.approver_user_id,
      displayName: s.approver_name,
      email: s.approver_email,
      departmentId: null,
      jobTitle: null,
      signatureStoragePath: null,
      signatureSha256: null
    }))
  );
</script>

<div class="flex flex-col gap-6">
  {#if !printMode}
    <DocumentHeader
      docNumber={data.document.doc_number}
      formName={data.document.form_name}
      status={data.document.status}
      drafterName={data.document.drafter_name}
      submittedAt={data.document.submitted_at}
      completedAt={data.document.completed_at}
    />
  {/if}

  <!-- 문서 메타데이터 -->
  {#if data.document.urgency !== '일반' || data.document.retention_period !== '5년' || data.document.security_level !== '일반'}
    <div class="flex flex-wrap gap-3 text-xs">
      {#if data.document.urgency === '긴급'}
        <span class="rounded bg-red-100 px-2 py-1 font-medium text-red-700">긴급</span>
      {/if}
      {#if data.document.retention_period !== '5년'}
        <span class="rounded bg-gray-100 px-2 py-1 text-gray-600">보관 {data.document.retention_period}</span>
      {/if}
      {#if data.document.security_level !== '일반'}
        <span class="rounded bg-orange-100 px-2 py-1 text-orange-700">{data.document.security_level}</span>
      {/if}
    </div>
  {/if}

  {#if !printMode && form?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {form.actionError}
    </p>
  {/if}

  <!-- 양식 내용 (read-only) -->
  <section class="rounded-lg border bg-white p-6">
    <h2 class="mb-4 text-sm font-semibold text-gray-700">내용</h2>
    <FormRenderer
      schema={data.document.form_schema_snapshot}
      tenantId={data.currentTenant.id}
      value={data.document.content}
      readonly
      onChange={() => {}}
    />
  </section>

  <!-- 첨부파일 -->
  {#if data.attachments.length > 0}
    <section class="rounded-lg border bg-white p-6">
      <AttachmentList attachments={data.attachments} downloadUrls={data.downloadUrls} />
    </section>
  {/if}

  <!-- 결재선 (read-only) -->
  <section class="rounded-lg border bg-white p-6">
    <!-- v2.3 M1: StampLine (가로 도장) -->
    <div class="mb-4">
      <StampLine
        steps={data.steps.map((s) => ({
          name: s.approver_name,
          title: '',
          status: (s.status === 'approved' ? 'approved' : s.status === 'rejected' ? 'rejected' : s.status === 'skipped' ? 'skipped' : 'pending'),
          stepType: s.step_type ?? 'approval'
        }))}
        drafterName={data.document.drafter_name}
      />
    </div>

    <ApprovalLine line={data.approvalLineReadonly} members={membersForLine} editable={false} />
    <DocumentSteps steps={data.steps} />
  </section>

  {#if !printMode}
    <!-- PDF 다운로드 버튼 -->
    <div class="flex justify-end">
      <a
        href="/t/{page.params.tenantSlug}/approval/documents/{data.document.id}/pdf"
        class="inline-flex items-center gap-2 rounded-lg border bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
      >
        PDF 다운로드
      </a>
    </div>

    <!-- 결재 액션 패널 -->
    {#if data.canApprove || data.canAgree || data.canWithdraw || data.canComment}
      <ApprovalPanel
        canApprove={data.canApprove}
        canAgree={data.canAgree}
        canWithdraw={data.canWithdraw}
        canComment={data.canComment}
        isProxyApproval={data.isProxyApproval}
      />
    {/if}

    <!-- v2.2 M5: 재기안 / M6: 독촉 -->
    {#if data.document.drafter_id === data.user?.id}
      <div class="flex items-center gap-2">
        {#if data.document.status === 'rejected'}
          <form method="POST" action="?/resubmit" use:enhance={({ }) => {
            return async ({ result }) => {
              if (result.type === 'success' && result.data?.resubmitRedirect) {
                window.location.href = result.data.resubmitRedirect as string;
              }
            };
          }}>
            <button type="submit" class="rounded border bg-blue-50 px-3 py-1.5 text-sm text-blue-700 hover:bg-blue-100">재기안</button>
          </form>
        {/if}
        {#if data.document.status === 'completed'}
          <form method="POST" action="?/requestCancel" use:enhance={({ }) => {
            return async ({ result }) => {
              if (result.type === 'success' && result.data?.cancelRedirect) {
                window.location.href = result.data.cancelRedirect as string;
              }
            };
          }}>
            <button type="submit" onclick={(e) => { if (!confirm('이 문서의 취소를 요청하시겠습니까? 취소 사유를 포함한 새 기안이 생성됩니다.')) e.preventDefault(); }}
              class="rounded border border-orange-300 bg-orange-50 px-3 py-1.5 text-sm text-orange-700 hover:bg-orange-100">
              취소 요청
            </button>
          </form>
        {/if}
        {#if data.document.status === 'in_progress' || data.document.status === 'pending_post_facto'}
          <form method="POST" action="?/remind" use:enhance={() => {
            return async ({ update }) => { await update({ reset: false }); };
          }}>
            <button type="submit" class="rounded border px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50">결재 독촉</button>
          </form>
          {#if form?.reminded}
            <span class="text-xs text-green-600">독촉 알림을 보냈습니다</span>
          {/if}
        {/if}
      </div>
    {/if}

    <!-- 이력 -->
    <section class="rounded-lg border bg-white p-6">
      <AuditTimeline audits={data.audits} />
    </section>
  {/if}
</div>
