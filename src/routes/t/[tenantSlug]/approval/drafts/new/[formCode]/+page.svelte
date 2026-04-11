<script lang="ts">
  import { enhance } from '$app/forms';
  import { untrack } from 'svelte';
  import FormRenderer from '$lib/components/FormRenderer.svelte';
  import ApprovalLine from '$lib/components/ApprovalLine.svelte';
  import type { ApprovalLineItem } from '$lib/types/approval';
  import type { UploadedAttachment } from '$lib/client/uploadAttachment';

  let { data, form } = $props();

  // Form 콘텐츠 ($state)
  let content = $state<Record<string, unknown>>({});

  // 결재선 ($state, 기본값은 양식의 default_approval_line — 초기값만 캡처)
  let approvalLine = $state<ApprovalLineItem[]>(
    untrack(() => [...data.form.defaultApprovalLine])
  );

  // 임시저장된 문서 ID (저장 후 서버가 반환)
  let documentId = $state<string | null>(null);

  // 제출 상태
  let submittingSave = $state(false);
  let submittingSubmit = $state(false);

  // 첨부파일은 content 안의 attachment-type 필드에 저장되므로
  // 여기서 한 번에 모아서 서버로 보낼 때 ID만 추출.
  function collectAttachmentIds(): string[] {
    const ids: string[] = [];
    for (const field of data.form.schema.fields) {
      if (field.type === 'attachment') {
        const items = content[field.id] as UploadedAttachment[] | undefined;
        if (items && items.length > 0) {
          for (const a of items) ids.push(a.id);
        }
      }
    }
    return ids;
  }
</script>

<div class="flex flex-col gap-6">
  <div>
    <h1 class="text-2xl font-bold">{data.form.name}</h1>
    {#if data.form.description}
      <p class="mt-1 text-sm text-gray-500">{data.form.description}</p>
    {/if}
  </div>

  <!-- 양식 작성 -->
  <section class="rounded-lg border bg-white p-6">
    <h2 class="mb-4 text-sm font-semibold text-gray-700">내용</h2>
    <FormRenderer
      schema={data.form.schema}
      tenantId={data.currentTenant.id}
      value={content}
      errors={form?.errors?.fields ?? {}}
      onChange={(next) => (content = next)}
    />
  </section>

  <!-- 결재선 -->
  <section class="rounded-lg border bg-white p-6">
    <ApprovalLine
      line={approvalLine}
      members={data.members}
      editable
      onChange={(next) => (approvalLine = next)}
    />
  </section>

  <!-- 에러 표시 -->
  {#if form?.errors?.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {form.errors.form}
    </p>
  {/if}

  <!-- 액션 버튼 -->
  <!-- 주의: content / approvalLine / attachmentIds 는 $state 객체라
       hidden input의 reactive attribute로 주입하면 submit 시점에 stale할 수 있음.
       use:enhance의 formData 인터셉트로 **직접** 주입해서 레이스 컨디션 제거. -->
  <div class="flex items-center justify-end gap-2">
    <!-- 임시저장 -->
    <form
      method="POST"
      action="?/saveDraft"
      use:enhance={({ formData }) => {
        formData.set('formId', data.form.id);
        formData.set('content', JSON.stringify(content));
        if (documentId) formData.set('documentId', documentId);
        submittingSave = true;
        return async ({ update, result }) => {
          await update({ reset: false });
          if (result.type === 'success' && result.data?.documentId) {
            documentId = result.data.documentId as string;
          }
          submittingSave = false;
        };
      }}
    >
      <button
        type="submit"
        disabled={submittingSave || submittingSubmit}
        class="rounded border px-4 py-2 text-sm hover:bg-gray-50 disabled:opacity-50"
      >
        {submittingSave ? '저장 중…' : '임시저장'}
      </button>
    </form>

    <!-- 상신 -->
    <form
      method="POST"
      action="?/submit"
      use:enhance={({ formData }) => {
        formData.set('formId', data.form.id);
        formData.set('content', JSON.stringify(content));
        formData.set('approvalLine', JSON.stringify(approvalLine));
        formData.set('attachmentIds', JSON.stringify(collectAttachmentIds()));
        if (documentId) formData.set('documentId', documentId);
        submittingSubmit = true;
        return async ({ update }) => {
          await update();
          submittingSubmit = false;
        };
      }}
    >
      <button
        type="submit"
        disabled={submittingSubmit || submittingSave || approvalLine.length === 0}
        class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
      >
        {submittingSubmit ? '상신 중…' : '상신'}
      </button>
    </form>
  </div>
</div>
