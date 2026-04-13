<script lang="ts">
  import { enhance } from '$app/forms';
  import { WORK_TYPE_LABELS, type WorkType } from '$lib/types/groupware';

  let { data } = $props();

  const todayRecord = $derived(data.todayRecord);
  const hasClockedIn = $derived(!!todayRecord?.clock_in);
  const hasClockedOut = $derived(!!todayRecord?.clock_out);

  function formatTime(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }

  function formatDate(dateStr: string): string {
    const d = new Date(dateStr + 'T00:00:00');
    return `${d.getMonth() + 1}/${d.getDate()} (${['일','월','화','수','목','금','토'][d.getDay()]})`;
  }
</script>

<h1 class="text-xl font-bold mb-6">근태관리</h1>

<!-- Today's status -->
<div class="rounded-lg border bg-white p-6 mb-6">
  <h2 class="text-sm font-semibold text-gray-500 mb-3">오늘 출퇴근</h2>
  <div class="flex items-center gap-6">
    <div>
      <span class="text-xs text-gray-400">출근</span>
      <p class="text-lg font-mono">{formatTime(todayRecord?.clock_in ?? null)}</p>
    </div>
    <div>
      <span class="text-xs text-gray-400">퇴근</span>
      <p class="text-lg font-mono">{formatTime(todayRecord?.clock_out ?? null)}</p>
    </div>
    {#if todayRecord}
      <span class="text-xs px-2 py-0.5 rounded {todayRecord.work_type === 'late' ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}">
        {WORK_TYPE_LABELS[todayRecord.work_type as WorkType] ?? todayRecord.work_type}
      </span>
    {/if}
    <div class="ml-auto flex gap-2">
      {#if !hasClockedIn}
        <form method="POST" action="?/clockIn" use:enhance>
          <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
            출근하기
          </button>
        </form>
      {:else if !hasClockedOut}
        <form method="POST" action="?/clockOut" use:enhance>
          <button type="submit" class="rounded bg-gray-600 px-4 py-2 text-sm text-white hover:bg-gray-700">
            퇴근하기
          </button>
        </form>
      {:else}
        <span class="text-sm text-gray-500 py-2">오늘 근무 완료</span>
      {/if}
    </div>
  </div>
</div>

<!-- Monthly records -->
<div class="rounded-lg border bg-white overflow-hidden">
  <div class="px-4 py-3 border-b">
    <h2 class="text-sm font-semibold text-gray-700">{data.year}년 {data.month}월 근태 기록</h2>
  </div>
  <table class="w-full text-sm">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-4 py-2 text-left font-medium text-gray-500">날짜</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">출근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">퇴근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">근무유형</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">비고</th>
      </tr>
    </thead>
    <tbody>
      {#each data.records as rec (rec.id)}
        <tr class="border-t">
          <td class="px-4 py-2 font-mono text-xs">{formatDate(rec.work_date)}</td>
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
          <td colspan="5" class="px-4 py-8 text-center text-gray-400">이번 달 기록이 없습니다</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
