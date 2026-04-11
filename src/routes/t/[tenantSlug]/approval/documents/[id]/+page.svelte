<script lang="ts">
  import DocumentHeader from '$lib/components/DocumentHeader.svelte';
  import FormRenderer from '$lib/components/FormRenderer.svelte';
  import ApprovalLine from '$lib/components/ApprovalLine.svelte';
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

    <!-- 각 step의 상태/코멘트 추가 정보 -->
    <ul class="mt-4 flex flex-col gap-2">
      {#each data.steps as s (s.id)}
        <li class="rounded border bg-gray-50 px-3 py-2 text-sm">
          <div class="flex items-center gap-2">
            <span class="w-6 text-gray-500">{s.step_index + 1}</span>
            <span class="flex-1 truncate font-medium">{s.approver_name}</span>
            <span
              class="rounded px-2 py-0.5 text-xs"
              class:bg-yellow-100={s.status === 'pending'}
              class:text-yellow-800={s.status === 'pending'}
              class:bg-green-100={s.status === 'approved'}
              class:text-green-800={s.status === 'approved'}
              class:bg-red-100={s.status === 'rejected'}
              class:text-red-800={s.status === 'rejected'}
              class:bg-gray-200={s.status === 'skipped'}
              class:text-gray-600={s.status === 'skipped'}
            >
              {s.status === 'pending'
                ? '대기'
                : s.status === 'approved'
                  ? '승인'
                  : s.status === 'rejected'
                    ? '반려'
                    : '건너뜀'}
            </span>
          </div>
          {#if s.comment}
            <div class="mt-1 whitespace-pre-wrap pl-8 text-xs text-gray-600">{s.comment}</div>
          {/if}
        </li>
      {/each}
    </ul>
  </section>

  <!-- 결재 액션 패널 -->
  {#if data.canApprove || data.canWithdraw || data.canComment}
    <ApprovalPanel
      canApprove={data.canApprove}
      canWithdraw={data.canWithdraw}
      canComment={data.canComment}
    />
  {/if}

  <!-- 이력 -->
  <section class="rounded-lg border bg-white p-6">
    <AuditTimeline audits={data.audits} />
  </section>
</div>
