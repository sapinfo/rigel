<script lang="ts">
  import AttendancePanel from '$lib/components/AttendancePanel.svelte';
  import AttendanceTable from '$lib/components/AttendanceTable.svelte';

  let { data } = $props();
</script>

<h1 class="text-xl font-bold mb-6">근태관리</h1>

<div class="mb-6">
  <AttendancePanel todayRecord={data.todayRecord} />
</div>

<AttendanceTable records={data.records} year={data.year} month={data.month} />
