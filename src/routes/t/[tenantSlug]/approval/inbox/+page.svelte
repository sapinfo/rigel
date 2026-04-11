<script lang="ts">
  import InboxTabs from '$lib/components/InboxTabs.svelte';
  import type { DocumentStatus } from '$lib/types/approval';

  let { data } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/approval/inbox`);

  const statusLabel: Record<DocumentStatus, string> = {
    draft: '임시저장',
    in_progress: '진행중',
    completed: '완료',
    rejected: '반려',
    withdrawn: '회수'
  };

  function fmt(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleString('ko-KR', {
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function documentHref(id: string): string {
    return `/t/${data.currentTenant.slug}/approval/documents/${id}`;
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold">결재함</h1>
    <p class="text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <InboxTabs active={data.tab} counts={data.counts} {baseHref} />

  {#if data.rows.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      해당 탭에 문서가 없습니다.
    </div>
  {:else}
    <ul class="flex flex-col gap-1">
      {#each data.rows as row (row.id)}
        <li>
          <a
            href={documentHref(row.id)}
            class="flex items-center gap-4 rounded border bg-white px-4 py-3 text-sm hover:bg-gray-50"
          >
            <span class="w-32 shrink-0 font-mono text-xs text-gray-500">{row.doc_number}</span>
            <span class="min-w-0 flex-1 truncate font-medium">{row.form_name}</span>
            <span class="w-24 shrink-0 truncate text-xs text-gray-600">{row.drafter_name}</span>
            <span
              class="w-16 shrink-0 rounded px-2 py-0.5 text-center text-xs"
              class:bg-yellow-100={row.status === 'draft'}
              class:text-yellow-800={row.status === 'draft'}
              class:bg-blue-100={row.status === 'in_progress'}
              class:text-blue-800={row.status === 'in_progress'}
              class:bg-green-100={row.status === 'completed'}
              class:text-green-800={row.status === 'completed'}
              class:bg-red-100={row.status === 'rejected'}
              class:text-red-800={row.status === 'rejected'}
              class:bg-gray-100={row.status === 'withdrawn'}
              class:text-gray-800={row.status === 'withdrawn'}
            >
              {statusLabel[row.status as DocumentStatus] ?? row.status}
            </span>
            <span class="w-28 shrink-0 text-right text-xs text-gray-400">
              {fmt(row.submitted_at ?? row.updated_at)}
            </span>
          </a>
        </li>
      {/each}
    </ul>
  {/if}
</div>
