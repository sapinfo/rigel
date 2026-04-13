<script lang="ts">
  import { page } from '$app/state';
  import { WORK_TYPE_LABELS, type WorkType } from '$lib/types/groupware';

  let { data } = $props();

  const slug = $derived(page.params.tenantSlug);

  function formatTime(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="flex items-center justify-between mb-6">
  <h1 class="text-xl font-bold">근태 현황 ({data.year}년 {data.month}월)</h1>
  <a href={`/t/${slug}/admin/attendance/settings`} class="text-sm text-blue-600 hover:underline">근무 설정</a>
</div>

<div class="rounded-lg border bg-white overflow-hidden">
  <table class="w-full text-sm">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-4 py-2 text-left font-medium text-gray-500">이름</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">날짜</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">출근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">퇴근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">유형</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">비고</th>
      </tr>
    </thead>
    <tbody>
      {#each data.records as rec (rec.id)}
        <tr class="border-t">
          <td class="px-4 py-2">{rec.userName}</td>
          <td class="px-4 py-2 font-mono text-xs">{rec.work_date}</td>
          <td class="px-4 py-2 font-mono text-xs">{formatTime(rec.clock_in)}</td>
          <td class="px-4 py-2 font-mono text-xs">{formatTime(rec.clock_out)}</td>
          <td class="px-4 py-2">
            <span class="text-xs px-1.5 py-0.5 rounded {rec.work_type === 'late' ? 'bg-red-50 text-red-600' : 'bg-gray-100 text-gray-600'}">
              {WORK_TYPE_LABELS[rec.work_type as WorkType] ?? rec.work_type}
            </span>
          </td>
          <td class="px-4 py-2 text-xs text-gray-500">{rec.note ?? ''}</td>
        </tr>
      {:else}
        <tr>
          <td colspan="6" class="px-4 py-8 text-center text-gray-400">이번 달 근태 기록이 없습니다</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
