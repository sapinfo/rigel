<script lang="ts">
  import { WORK_TYPE_LABELS, type WorkType } from '$lib/types/groupware';

  interface Record {
    id: string;
    work_date: string;
    clock_in: string | null;
    clock_out: string | null;
    work_type: string;
    note: string | null;
    userName?: string;
  }

  interface Props {
    records: Record[];
    year: number;
    month: number;
    showName?: boolean;
  }

  let { records, year, month, showName = false }: Props = $props();

  function formatTime(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }

  function formatDate(dateStr: string): string {
    const d = new Date(dateStr + 'T00:00:00');
    return `${d.getMonth() + 1}/${d.getDate()} (${['일','월','화','수','목','금','토'][d.getDay()]})`;
  }
</script>

<div class="rounded-lg border bg-white overflow-hidden">
  <div class="px-4 py-3 border-b">
    <h2 class="text-sm font-semibold text-gray-700">{year}년 {month}월 근태 기록</h2>
  </div>
  <table class="w-full text-sm">
    <thead class="bg-gray-50">
      <tr>
        {#if showName}
          <th class="px-4 py-2 text-left font-medium text-gray-500">이름</th>
        {/if}
        <th class="px-4 py-2 text-left font-medium text-gray-500">날짜</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">출근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">퇴근</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">근무유형</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">비고</th>
      </tr>
    </thead>
    <tbody>
      {#each records as rec (rec.id)}
        <tr class="border-t">
          {#if showName}
            <td class="px-4 py-2">{rec.userName ?? ''}</td>
          {/if}
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
          <td colspan={showName ? 6 : 5} class="px-4 py-8 text-center text-gray-400">이번 달 기록이 없습니다</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
