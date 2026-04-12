<script lang="ts">
  import { enhance } from '$app/forms';
  import InboxTabs from '$lib/components/InboxTabs.svelte';
  import type { DocumentStatus } from '$lib/types/approval';

  let { data, form } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/approval/inbox`);

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
    return new Date(iso).toLocaleString('ko-KR', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
  }

  function documentHref(id: string): string {
    return `/t/${data.currentTenant.slug}/approval/documents/${id}`;
  }

  // 검색 + 페이징
  let searchQuery = $state('');
  let currentPage = $state(1);
  const perPage = 20;

  const filteredRows = $derived(
    searchQuery.trim()
      ? data.rows.filter((r) =>
          r.doc_number.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.form_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          r.drafter_name.toLowerCase().includes(searchQuery.toLowerCase())
        )
      : data.rows
  );

  const totalPages = $derived(Math.ceil(filteredRows.length / perPage));
  const pagedRows = $derived(filteredRows.slice((currentPage - 1) * perPage, currentPage * perPage));

  // v2.2 M3: 일괄 결재
  let selectedIds = $state<Set<string>>(new Set());
  let batchComment = $state('');
  let showBatchDialog = $state<'approve' | 'reject' | null>(null);
  let batchFormEl = $state<HTMLFormElement | null>(null);
  let batchAction = $state('');

  function toggleSelect(id: string) {
    const next = new Set(selectedIds);
    if (next.has(id)) next.delete(id); else next.add(id);
    selectedIds = next;
  }

  function toggleAll() {
    if (selectedIds.size === data.rows.length) {
      selectedIds = new Set();
    } else {
      selectedIds = new Set(data.rows.map((r) => r.id));
    }
  }

  function submitBatch(action: 'batchApprove' | 'batchReject') {
    batchAction = action;
    requestAnimationFrame(() => batchFormEl?.requestSubmit());
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold">결재함</h1>
    <p class="text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <InboxTabs active={data.tab} counts={data.counts} {baseHref} />

  <!-- 검색 -->
  <div class="flex items-center gap-2">
    <input type="text" bind:value={searchQuery} placeholder="문서번호, 양식명, 기안자 검색" class="flex-1 rounded border px-3 py-1.5 text-sm" oninput={() => currentPage = 1} />
    {#if searchQuery}
      <button type="button" onclick={() => { searchQuery = ''; currentPage = 1; }} class="text-xs text-gray-500">초기화</button>
    {/if}
    <span class="text-xs text-gray-400">{filteredRows.length}건</span>
  </div>

  <!-- 일괄 결재 결과 -->
  {#if form?.batchResult}
    {@const results = form.batchResult as { id: string; ok: boolean; error?: string }[]}
    {@const ok = results.filter(r => r.ok).length}
    {@const fail_ = results.filter(r => !r.ok).length}
    <div class="rounded border px-3 py-2 text-sm" class:border-green-300={fail_ === 0} class:bg-green-50={fail_ === 0} class:border-red-300={fail_ > 0} class:bg-red-50={fail_ > 0}>
      {ok}건 처리 완료{#if fail_ > 0}, {fail_}건 실패{/if}
    </div>
  {/if}

  <!-- 일괄 결재 액션 바 (pending 탭 + 선택 > 0) -->
  {#if data.tab === 'pending' && selectedIds.size > 0}
    <div class="sticky top-0 z-10 flex items-center gap-3 rounded border bg-blue-50 px-4 py-2">
      <span class="text-sm font-medium">{selectedIds.size}건 선택</span>
      <button type="button" onclick={() => showBatchDialog = 'approve'} class="rounded bg-green-600 px-3 py-1 text-sm text-white">일괄 승인</button>
      <button type="button" onclick={() => showBatchDialog = 'reject'} class="rounded bg-red-600 px-3 py-1 text-sm text-white">일괄 반려</button>
      <button type="button" onclick={() => selectedIds = new Set()} class="ml-auto text-xs text-gray-500">선택 해제</button>
    </div>
  {/if}

  <!-- 일괄 결재 다이얼로그 -->
  {#if showBatchDialog}
    <div class="rounded border bg-white p-4 shadow">
      <p class="mb-2 text-sm font-medium">{showBatchDialog === 'approve' ? '일괄 승인' : '일괄 반려'} — {selectedIds.size}건</p>
      <textarea bind:value={batchComment} rows="2" placeholder="코멘트 (선택)" class="mb-2 w-full rounded border px-3 py-2 text-sm"></textarea>
      <div class="flex gap-2">
        <button type="button" onclick={() => submitBatch(showBatchDialog === 'approve' ? 'batchApprove' : 'batchReject')}
          class="rounded px-4 py-1.5 text-sm text-white {showBatchDialog === 'approve' ? 'bg-green-600' : 'bg-red-600'}">
          확인
        </button>
        <button type="button" onclick={() => { showBatchDialog = null; batchComment = ''; }} class="rounded border px-4 py-1.5 text-sm">취소</button>
      </div>
    </div>
  {/if}

  <!-- 숨겨진 일괄 결재 폼 -->
  <form bind:this={batchFormEl} method="POST" action="?/{batchAction}" class="hidden" use:enhance={() => {
    return async ({ update }) => {
      await update({ reset: false });
      selectedIds = new Set();
      showBatchDialog = null;
      batchComment = '';
    };
  }}>
    <input type="hidden" name="documentIds" value={JSON.stringify([...selectedIds])} />
    <input type="hidden" name="comment" value={batchComment} />
  </form>

  {#if pagedRows.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      {searchQuery ? '검색 결과가 없습니다.' : '해당 탭에 문서가 없습니다.'}
    </div>
  {:else}
    <ul class="flex flex-col gap-1">
      {#each pagedRows as row (row.id)}
        <li>
          <div class="flex items-center gap-2 rounded border bg-white px-4 py-3 text-sm hover:bg-gray-50">
            <!-- 체크박스 (pending 탭만) -->
            {#if data.tab === 'pending'}
              <input type="checkbox" checked={selectedIds.has(row.id)} onchange={() => toggleSelect(row.id)} class="h-4 w-4 rounded border-gray-300" />
            {/if}

            <a href={documentHref(row.id)} class="flex flex-1 items-center gap-4">
              <span class="w-32 shrink-0 font-mono text-xs text-gray-500">{row.doc_number}</span>
              <!-- 긴급 배지 -->
              {#if row.urgency === '긴급'}
                <span class="rounded bg-red-100 px-1.5 py-0.5 text-[10px] font-medium text-red-700">긴급</span>
              {/if}
              <span class="min-w-0 flex-1 truncate font-medium">{row.form_name}</span>
              <span class="w-24 shrink-0 truncate text-xs text-gray-600">{row.drafter_name}</span>
              <span class="w-16 shrink-0 rounded px-2 py-0.5 text-center text-xs"
                class:bg-yellow-100={row.status === 'draft'} class:text-yellow-800={row.status === 'draft'}
                class:bg-blue-100={row.status === 'in_progress'} class:text-blue-800={row.status === 'in_progress'}
                class:bg-green-100={row.status === 'completed'} class:text-green-800={row.status === 'completed'}
                class:bg-red-100={row.status === 'rejected'} class:text-red-800={row.status === 'rejected'}
                class:bg-gray-100={row.status === 'withdrawn'} class:text-gray-800={row.status === 'withdrawn'}>
                {statusLabel[row.status as DocumentStatus] ?? row.status}
              </span>
              <span class="w-28 shrink-0 text-right text-xs text-gray-400">{fmt(row.submitted_at ?? row.updated_at)}</span>
            </a>
          </div>
        </li>
      {/each}
    </ul>

    <!-- 전체 선택 + 페이지네이션 -->
    <div class="flex items-center justify-between">
      {#if data.tab === 'pending' && pagedRows.length > 1}
        <button type="button" onclick={toggleAll} class="text-xs text-gray-500 hover:underline">
          {selectedIds.size === pagedRows.length ? '전체 선택 해제' : '전체 선택'}
        </button>
      {:else}
        <span></span>
      {/if}

      {#if totalPages > 1}
        <div class="flex items-center gap-1">
          <button type="button" disabled={currentPage <= 1} onclick={() => currentPage--} class="rounded border px-2 py-0.5 text-xs disabled:opacity-30">이전</button>
          <span class="text-xs text-gray-500">{currentPage} / {totalPages}</span>
          <button type="button" disabled={currentPage >= totalPages} onclick={() => currentPage++} class="rounded border px-2 py-0.5 text-xs disabled:opacity-30">다음</button>
        </div>
      {/if}
    </div>
  {/if}
</div>
