<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
</script>

<h1 class="text-xl font-bold mb-6">근무 시간 설정</h1>

{#if form?.success}
  <div class="mb-4 rounded bg-green-50 border border-green-200 px-4 py-2 text-sm text-green-700">
    저장되었습니다.
  </div>
{/if}

<form method="POST" action="?/save" use:enhance class="rounded-lg border bg-white p-6 max-w-md space-y-4">
  <label class="block">
    <span class="block text-sm font-medium text-gray-700 mb-1">출근 시간</span>
    <input type="time" name="work_start_time" value={data.settings.work_start_time} required
      class="w-full rounded border px-3 py-2 text-sm" />
  </label>

  <label class="block">
    <span class="block text-sm font-medium text-gray-700 mb-1">퇴근 시간</span>
    <input type="time" name="work_end_time" value={data.settings.work_end_time} required
      class="w-full rounded border px-3 py-2 text-sm" />
  </label>

  <label class="block">
    <span class="block text-sm font-medium text-gray-700 mb-1">지각 허용 시간 (분)</span>
    <input type="number" name="late_threshold_minutes" value={data.settings.late_threshold_minutes}
      min="0" max="120" required class="w-full rounded border px-3 py-2 text-sm" />
    <p class="text-xs text-gray-400 mt-1">출근 시간 + 허용 시간 이후 출근 시 지각 처리</p>
  </label>

  <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
    저장
  </button>
</form>
