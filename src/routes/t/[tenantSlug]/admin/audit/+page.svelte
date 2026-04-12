<script lang="ts">
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

  function fmt(iso: string): string {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit'
    });
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">감사 로그</h1>
    <span class="text-sm text-gray-500">총 {data.totalCount}건</span>
  </div>

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
            <span class="text-xs text-gray-400">{log.actorEmail}</span>
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
            {JSON.stringify(log.payload).slice(0, 60)}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>

  <!-- 페이지네이션 -->
  {#if totalPages > 1}
    <div class="flex items-center justify-center gap-1">
      {#each Array.from({ length: totalPages }, (_, i) => i + 1) as p (p)}
        <a
          href="?page={p}"
          class="rounded px-3 py-1 text-sm"
          class:bg-blue-600={p === data.currentPage}
          class:text-white={p === data.currentPage}
          class:hover:bg-gray-100={p !== data.currentPage}
        >
          {p}
        </a>
      {/each}
    </div>
  {/if}
</div>
