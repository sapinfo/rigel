<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
  const slug = data.currentTenant.slug;

  let showReserve = $state(false);
  let selRoomId = $state('');
  let resTitle = $state('');
  let resStart = $state('');
  let resEnd = $state('');

  function formatTime(iso: string) {
    return new Date(iso).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
  }

  function reservationsForRoom(roomId: string) {
    return data.reservations.filter((r) => r.room_id === roomId);
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-xl font-bold">회의실 예약</h1>
    <div class="flex gap-2">
      <input
        type="date"
        value={data.selectedDate}
        onchange={(e) => {
          const target = e.target as HTMLInputElement;
          window.location.href = `?date=${target.value}`;
        }}
        class="rounded border px-3 py-1.5 text-sm"
      />
      <button type="button" onclick={() => (showReserve = !showReserve)} class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">
        + 예약
      </button>
    </div>
  </div>

  {#if form?.error}
    <p class="rounded bg-red-50 p-3 text-sm text-red-600">{form.error}</p>
  {/if}

  {#if showReserve}
    <form method="POST" action="?/reserve" use:enhance class="rounded-lg border bg-white p-4 space-y-3">
      <label class="block">
        <span class="text-sm font-medium">회의실</span>
        <select name="room_id" bind:value={selRoomId} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required>
          <option value="">선택</option>
          {#each data.rooms as room (room.id)}
            <option value={room.id}>{room.name}{room.capacity ? ` (${room.capacity}인)` : ''}</option>
          {/each}
        </select>
      </label>
      <label class="block">
        <span class="text-sm font-medium">제목</span>
        <input name="title" bind:value={resTitle} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <label class="block">
          <span class="text-sm font-medium">시작</span>
          <input type="datetime-local" name="start_at" bind:value={resStart} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
        </label>
        <label class="block">
          <span class="text-sm font-medium">종료</span>
          <input type="datetime-local" name="end_at" bind:value={resEnd} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
        </label>
      </div>
      <div class="flex gap-2">
        <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">예약</button>
        <button type="button" onclick={() => (showReserve = false)} class="rounded border px-4 py-2 text-sm">취소</button>
      </div>
    </form>
  {/if}

  <!-- Room cards -->
  {#if data.rooms.length === 0}
    <p class="text-sm text-gray-500">등록된 회의실이 없습니다.</p>
  {:else}
    <div class="space-y-3">
      {#each data.rooms as room (room.id)}
        {@const roomRes = reservationsForRoom(room.id)}
        <div class="rounded-lg border bg-white p-4">
          <div class="flex items-center gap-2">
            <h2 class="font-semibold">{room.name}</h2>
            {#if room.location}
              <span class="text-xs text-gray-400">{room.location}</span>
            {/if}
            {#if room.capacity}
              <span class="text-xs rounded bg-gray-100 px-1.5 py-0.5">{room.capacity}인</span>
            {/if}
          </div>
          {#if roomRes.length === 0}
            <p class="mt-2 text-xs text-gray-400">예약 없음</p>
          {:else}
            <div class="mt-2 space-y-1">
              {#each roomRes as res (res.id)}
                <div class="flex items-center justify-between rounded bg-blue-50 px-3 py-1.5 text-xs">
                  <span>
                    <span class="font-medium">{formatTime(res.start_at)} ~ {formatTime(res.end_at)}</span>
                    <span class="ml-2">{res.title}</span>
                    <span class="ml-1 text-gray-400">({res.reserved_by_name})</span>
                  </span>
                  <form method="POST" action="?/cancelReservation" use:enhance class="inline">
                    <input type="hidden" name="id" value={res.id} />
                    <button type="submit" class="text-red-500 hover:underline">취소</button>
                  </form>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <a href="/t/{slug}/calendar" class="text-sm text-gray-500 hover:underline">&larr; 캘린더</a>
</div>
