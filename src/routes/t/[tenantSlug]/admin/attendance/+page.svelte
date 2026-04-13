<script lang="ts">
  import { page } from '$app/state';
  import AttendanceTable from '$lib/components/AttendanceTable.svelte';

  let { data } = $props();
  const slug = $derived(page.params.tenantSlug);
</script>

<div class="flex items-center justify-between mb-6">
  <h1 class="text-xl font-bold">근태 현황 ({data.year}년 {data.month}월)</h1>
  <a href={`/t/${slug}/admin/attendance/settings`} class="text-sm text-blue-600 hover:underline">근무 설정</a>
</div>

<AttendanceTable records={data.records} year={data.year} month={data.month} showName={true} />
