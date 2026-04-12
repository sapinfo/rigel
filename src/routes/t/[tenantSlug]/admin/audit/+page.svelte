<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/state';

  let { data } = $props();

  const totalPages = Math.ceil(data.totalCount / data.perPage);

  const actionLabels: Record<string, string> = {
    draft_saved: '임시저장',
    submit: '상신',
    approve: '승인',
    reject: '반려',
    withdraw: '회수',
    comment: '코멘트',
    delegated: '전결',
    approved_by_proxy: '대리승인',
    submitted_post_facto: '후결상신',
    auto_delegated: '자동위임',
    agreed: '합의동의',
    disagreed: '합의부동의'
  };

  const actionOptions = Object.entries(actionLabels);

  function fmt(iso: string): string {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit'
    });
  }

  function applyFilter(params: Record<string, string>) {
    const u = new URL(page.url);
    for (const [k, v] of Object.entries(params)) {
      if (v) u.searchParams.set(k, v);
      else u.searchParams.delete(k);
    }
    u.searchParams.set('page', '1');
    goto(u.toString(), { replaceState: true });
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">감사 로그</h1>
    <span class="text-sm text-gray-500">총 {data.totalCount}건</span>
  </div>

  <!-- 필터 -->
  <div class="flex flex-wrap items-center gap-2">
    <input
      type="text"
      value={data.search}
      placeholder="사용자 이름/이메일 검색"
      class="rounded border px-3 py-1.5 text-sm"
      onchange={(e) => applyFilter({ q: e.currentTarget.value })}
    />
    <select
      value={data.actionFilter}
      class="rounded border px-3 py-1.5 text-sm"
      onchange={(e) => applyFilter({ action: e.currentTarget.value })}
    >
      <option value="">전체 액션</option>
      {#each actionOptions as [key, label] (key)}
        <option value={key}>{label}</option>
      {/each}
    </select>
    {#if data.actionFilter || data.search}
      <button type="button" onclick={() => applyFilter({ action: '', q: '' })} class="text-xs text-gray-500 hover:underline">필터 초기화</button>
    {/if}
  </div>

  <!-- 테이블 -->
  <table class="w-full rounded-lg border bg-white text-sm">
    <thead>
      <tr class="border-b bg-gray-50 text-left text-xs text-gray-500">
        <th class="px-3 py-2">시간</th>
        <th class="px-3 py-2">사용자</th>
        <th class="px-3 py-2">액션</th>
        <th class="px-3 py-2">문서</th>
        <th class="px-3 py-2">상세</th>
      </tr>
    </thead>
    <tbody>
      {#each data.rows as log (log.id)}
        <tr class="border-b last:border-b-0">
          <td class="px-3 py-2 text-xs text-gray-400">{fmt(log.createdAt)}</td>
          <td class="px-3 py-2">
            <span class="font-medium">{log.actorName}</span>
            <span class="block text-xs text-gray-400">{log.actorEmail}</span>
          </td>
          <td class="px-3 py-2">
            <span class="rounded bg-gray-100 px-1.5 py-0.5 text-xs">{actionLabels[log.action] ?? log.action}</span>
          </td>
          <td class="px-3 py-2">
            {#if log.documentId}
              <a href="/t/{data.currentTenant.slug}/approval/documents/{log.documentId}" class="text-xs text-blue-600 hover:underline">
                {log.documentId.slice(0, 8)}…
              </a>
            {:else}
              <span class="text-xs text-gray-300">-</span>
            {/if}
          </td>
          <td class="max-w-48 truncate px-3 py-2 font-mono text-xs text-gray-400" title={JSON.stringify(log.payload)}>
            {JSON.stringify(log.payload).slice(0, 50)}
          </td>
        </tr>
      {/each}
      {#if data.rows.length === 0}
        <tr>
          <td colspan="5" class="px-3 py-8 text-center text-sm text-gray-400">로그가 없습니다.</td>
        </tr>
      {/if}
    </tbody>
  </table>

  <!-- 페이지네이션 -->
  {#if totalPages > 1}
    <div class="flex items-center justify-center gap-2">
      <a href="?page={Math.max(1, data.currentPage - 1)}&action={data.actionFilter}&q={data.search}"
         class="rounded border px-3 py-1 text-xs" class:opacity-30={data.currentPage <= 1}>이전</a>
      <span class="text-xs text-gray-500">{data.currentPage} / {totalPages}</span>
      <a href="?page={Math.min(totalPages, data.currentPage + 1)}&action={data.actionFilter}&q={data.search}"
         class="rounded border px-3 py-1 text-xs" class:opacity-30={data.currentPage >= totalPages}>다음</a>
    </div>
  {/if}
</div>
