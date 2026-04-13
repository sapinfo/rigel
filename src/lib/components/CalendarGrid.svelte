<script lang="ts">
  interface CalEvent {
    id: string;
    title: string;
    start_at: string;
    all_day: boolean;
    event_type: string;
  }

  interface Props {
    year: number;
    month: number;
    events: CalEvent[];
  }

  let { year, month, events }: Props = $props();

  const EVENT_COLORS: Record<string, string> = {
    personal: 'bg-blue-100 text-blue-800',
    department: 'bg-green-100 text-green-800',
    company: 'bg-purple-100 text-purple-800'
  };

  const daysInMonth = $derived(new Date(year, month, 0).getDate());
  const firstDow = $derived(new Date(year, month - 1, 1).getDay());
  const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  function eventsForDay(day: number) {
    const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return events.filter((e) => e.start_at.slice(0, 10) === dateStr);
  }

  function formatTime(iso: string) {
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="rounded-lg border bg-white overflow-hidden">
  <div class="grid grid-cols-7 border-b bg-gray-50 text-center text-xs text-gray-500">
    {#each dayLabels as label}
      <div class="py-2 {label === '일' ? 'text-red-400' : label === '토' ? 'text-blue-400' : ''}">{label}</div>
    {/each}
  </div>
  <div class="grid grid-cols-7">
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
