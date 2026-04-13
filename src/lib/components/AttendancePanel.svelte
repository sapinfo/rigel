<script lang="ts">
  import { enhance } from '$app/forms';
  import { WORK_TYPE_LABELS, type WorkType } from '$lib/types/groupware';

  interface Props {
    todayRecord: { clock_in: string | null; clock_out: string | null; work_type: string } | null;
  }

  let { todayRecord }: Props = $props();

  const hasClockedIn = $derived(!!todayRecord?.clock_in);
  const hasClockedOut = $derived(!!todayRecord?.clock_out);

  function formatTime(iso: string | null): string {
    if (!iso) return '-';
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="rounded-lg border bg-white p-6">
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
          <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">출근하기</button>
        </form>
      {:else if !hasClockedOut}
        <form method="POST" action="?/clockOut" use:enhance>
          <button type="submit" class="rounded bg-gray-600 px-4 py-2 text-sm text-white hover:bg-gray-700">퇴근하기</button>
        </form>
      {:else}
        <span class="text-sm text-gray-500 py-2">오늘 근무 완료</span>
      {/if}
    </div>
  </div>
</div>
