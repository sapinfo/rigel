<script lang="ts">
  import DocumentHeader from '$lib/components/DocumentHeader.svelte';
  import FormRenderer from '$lib/components/FormRenderer.svelte';
  import ApprovalLine from '$lib/components/ApprovalLine.svelte';
  import DocumentSteps from '$lib/components/DocumentSteps.svelte';
  import AttachmentList from '$lib/components/AttachmentList.svelte';
  import AuditTimeline from '$lib/components/AuditTimeline.svelte';
  import ApprovalPanel from '$lib/components/ApprovalPanel.svelte';
  import type { ProfileLite } from '$lib/types/approval';

  let { data, form } = $props();

  // ApprovalLine needs ProfileLite[] for display
  const membersForLine = $derived<ProfileLite[]>(
    data.steps.map((s) => ({
      id: s.approver_user_id,
      displayName: s.approver_name,
      email: s.approver_email,
      departmentId: null,
      jobTitle: null
    }))
  );
</script>

<div class="flex flex-col gap-6">
  <DocumentHeader
    docNumber={data.document.doc_number}
    formName={data.document.form_name}
    status={data.document.status}
    drafterName={data.document.drafter_name}
    submittedAt={data.document.submitted_at}
    completedAt={data.document.completed_at}
  />

  {#if form?.actionError}
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
</div>
