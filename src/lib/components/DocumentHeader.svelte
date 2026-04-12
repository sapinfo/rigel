<script lang="ts">
  import type { DocumentStatus } from '$lib/types/approval';

  type Props = {
    docNumber: string;
    formName: string;
    status: DocumentStatus;
    drafterName: string | null;
    submittedAt: string | null;
    completedAt: string | null;
  };

  let { docNumber, formName, status, drafterName, submittedAt, completedAt }: Props = $props();

  const statusLabel: Record<DocumentStatus, string> = {
    draft: '임시저장',
    in_progress: '진행중',
    pending_post_facto: '후결 진행중',
    completed: '완료',
    rejected: '반려',
    withdrawn: '회수'
  };

  function fmt(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
</script>

<header class="flex items-start justify-between border-b pb-4">
  <div class="min-w-0 flex-1">
    <div class="text-xs text-gray-500">{docNumber}</div>
    <h1 class="mt-1 text-2xl font-bold">{formName}</h1>
    {#if drafterName}
      <div class="mt-1 text-sm text-gray-600">기안자: {drafterName}</div>
    {/if}
  </div>
  <div class="text-right">
    <span
      class="inline-block rounded px-2 py-1 text-xs font-medium"
      class:bg-yellow-100={status === 'draft'}
      class:text-yellow-800={status === 'draft'}
      class:bg-blue-100={status === 'in_progress'}
      class:text-blue-800={status === 'in_progress'}
      class:bg-orange-100={status === 'pending_post_facto'}
      class:text-orange-800={status === 'pending_post_facto'}
      class:bg-green-100={status === 'completed'}
      class:text-green-800={status === 'completed'}
      class:bg-red-100={status === 'rejected'}
      class:text-red-800={status === 'rejected'}
      class:bg-gray-100={status === 'withdrawn'}
      class:text-gray-800={status === 'withdrawn'}
    >
      {statusLabel[status]}
    </span>
    <div class="mt-2 text-xs text-gray-500">
      {#if status === 'completed' && completedAt}
        완료: {fmt(completedAt)}
      {:else if submittedAt}
        상신: {fmt(submittedAt)}
      {/if}
    </div>
  </div>
</header>
