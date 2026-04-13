<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
  const slug = data.currentTenant.slug;

  let showCreate = $state(false);
  let newTitle = $state('');
  let newStartAt = $state('');
  let newEndAt = $state('');
  let newAllDay = $state(false);
  let newEventType = $state('personal');
  let newColor = $state('#3b82f6');
  let newDesc = $state('');

  const EVENT_TYPE_LABELS: Record<string, string> = {
    personal: '개인',
    department: '부서',
    company: '전사'
  };

  const EVENT_COLORS: Record<string, string> = {
    personal: 'bg-blue-100 text-blue-800',
    department: 'bg-green-100 text-green-800',
    company: 'bg-purple-100 text-purple-800'
  };

  // Build calendar grid
  const daysInMonth = new Date(data.year, data.month, 0).getDate();
  const firstDow = new Date(data.year, data.month - 1, 1).getDay(); // 0=Sun
  const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  function eventsForDay(day: number) {
    const dateStr = `${data.year}-${String(data.month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return data.events.filter((e) => {
      const eDate = e.start_at.slice(0, 10);
      return eDate === dateStr;
    });
  }

  function formatTime(iso: string) {
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }

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
    <form method="POST" action="?/create" use:enhance class="rounded-lg border bg-white p-4 space-y-3">
      <label class="block">
        <span class="text-sm font-medium">제목</span>
        <input name="title" bind:value={newTitle} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <label class="block">
          <span class="text-sm font-medium">시작</span>
          <input type="datetime-local" name="start_at" bind:value={newStartAt} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
        </label>
        <label class="block">
          <span class="text-sm font-medium">종료</span>
          <input type="datetime-local" name="end_at" bind:value={newEndAt} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
        </label>
      </div>
      <div class="flex flex-wrap gap-4">
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" name="all_day" bind:checked={newAllDay} /> 종일
        </label>
        <label class="block">
          <span class="text-sm font-medium">유형</span>
          <select name="event_type" bind:value={newEventType} class="ml-2 rounded border px-2 py-1 text-sm">
            <option value="personal">개인</option>
            {#if data.isAdmin}
              <option value="department">부서</option>
              <option value="company">전사</option>
            {/if}
          </select>
        </label>
        <label class="flex items-center gap-2 text-sm">
          <span>색상</span>
          <input type="color" name="color" bind:value={newColor} class="h-7 w-7 rounded border" />
        </label>
      </div>
      <label class="block">
        <span class="text-sm font-medium">설명</span>
        <textarea name="description" bind:value={newDesc} rows={2} class="mt-1 block w-full rounded border px-3 py-2 text-sm"></textarea>
      </label>
      <div class="flex gap-2">
        <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">등록</button>
        <button type="button" onclick={() => (showCreate = false)} class="rounded border px-4 py-2 text-sm">취소</button>
      </div>
    </form>
  {/if}

  <!-- Calendar grid -->
  <div class="rounded-lg border bg-white overflow-hidden">
    <div class="grid grid-cols-7 border-b bg-gray-50 text-center text-xs text-gray-500">
      {#each dayLabels as label}
        <div class="py-2 {label === '일' ? 'text-red-400' : label === '토' ? 'text-blue-400' : ''}">{label}</div>
      {/each}
    </div>
    <div class="grid grid-cols-7">
      <!-- Empty cells before first day -->
      {#each Array(firstDow) as _}
        <div class="min-h-[80px] border-b border-r p-1"></div>
      {/each}
      {#each Array.from({ length: daysInMonth }, (_, i) => i + 1) as day}
        {@const dayEvents = eventsForDay(day)}
        {@const dow = (firstDow + day - 1) % 7}
        <div class="min-h-[80px] border-b border-r p-1 {dow === 0 ? 'bg-red-50/30' : dow === 6 ? 'bg-blue-50/30' : ''}">
          <div class="text-xs font-medium {dow === 0 ? 'text-red-500' : dow === 6 ? 'text-blue-500' : 'text-gray-600'}">{day}</div>
          {#each dayEvents.slice(0, 3) as event}
            <div class="mt-0.5 truncate rounded px-1 text-[10px] {EVENT_COLORS[event.event_type] ?? 'bg-gray-100'}" title={event.title}>
              {#if !event.all_day}
                <span class="font-medium">{formatTime(event.start_at)}</span>
              {/if}
              {event.title}
            </div>
          {/each}
          {#if dayEvents.length > 3}
            <div class="text-[10px] text-gray-400 px-1">+{dayEvents.length - 3}건</div>
          {/if}
        </div>
      {/each}
    </div>
  </div>
</div>
