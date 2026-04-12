<script lang="ts">
  import DocumentHeader from '$lib/components/DocumentHeader.svelte';
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
    {#if data.canApprove || data.canWithdraw || data.canComment}
      <ApprovalPanel
        canApprove={data.canApprove}
        canWithdraw={data.canWithdraw}
        canComment={data.canComment}
        isProxyApproval={data.isProxyApproval}
      />
    {/if}

    <!-- 이력 -->
    <section class="rounded-lg border bg-white p-6">
      <AuditTimeline audits={data.audits} />
    </section>
  {/if}
</div>
