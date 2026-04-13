<script lang="ts">
  import CalendarGrid from '$lib/components/CalendarGrid.svelte';
  import EventForm from '$lib/components/EventForm.svelte';

  let { data, form } = $props();
  const slug = data.currentTenant.slug;

  let showCreate = $state(false);

  const EVENT_TYPE_LABELS: Record<string, string> = {
    personal: '개인',
    department: '부서',
    company: '전사'
  };

  const prevMonth = data.month === 1 ? { year: data.year - 1, month: 12 } : { year: data.year, month: data.month - 1 };
  const nextMonth = data.month === 12 ? { year: data.year + 1, month: 1 } : { year: data.year, month: data.month + 1 };
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <div class="flex items-center gap-3">
      <a href="?year={prevMonth.year}&month={prevMonth.month}" class="rounded border px-2 py-1 text-sm hover:bg-gray-50">&larr;</a>
      <h1 class="text-xl font-bold">{data.year}년 {data.month}월</h1>
      <a href="?year={nextMonth.year}&month={nextMonth.month}" class="rounded border px-2 py-1 text-sm hover:bg-gray-50">&rarr;</a>
    </div>
    <div class="flex gap-2">
      <a href="/t/{slug}/calendar/rooms" class="rounded border px-3 py-1.5 text-sm hover:bg-gray-50">회의실</a>
      <button type="button" onclick={() => (showCreate = !showCreate)} class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">
        + 일정
      </button>
    </div>
  </div>

  {#if form?.error}
    <p class="rounded bg-red-50 p-3 text-sm text-red-600">{form.error}</p>
  {/if}

  {#if showCreate}
    <EventForm isAdmin={data.isAdmin} onclose={() => (showCreate = false)} />
  {/if}

  <CalendarGrid year={data.year} month={data.month} events={data.events} />
</div>
