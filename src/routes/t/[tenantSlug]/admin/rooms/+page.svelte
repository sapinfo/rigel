<script lang="ts">
  import { enhance } from '$app/forms';

  let { data } = $props();

  let editingId = $state<string | null>(null);
  let showCreate = $state(false);
</script>

<h1 class="text-xl font-bold mb-6">회의실 관리</h1>

<button
  type="button"
  class="mb-4 rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
  onclick={() => (showCreate = !showCreate)}
>
  + 회의실 추가
</button>

{#if showCreate}
  <form method="POST" action="?/create" use:enhance={() => { return async ({ update }) => { showCreate = false; await update(); }; }} class="rounded border bg-gray-50 p-4 mb-4 flex gap-3 items-end">
    <label class="flex-1">
      <span class="block text-xs text-gray-500 mb-1">이름</span>
      <input name="name" required class="w-full rounded border px-2 py-1.5 text-sm" />
    </label>
    <label class="flex-1">
      <span class="block text-xs text-gray-500 mb-1">위치</span>
      <input name="location" class="w-full rounded border px-2 py-1.5 text-sm" />
    </label>
    <label class="w-24">
      <span class="block text-xs text-gray-500 mb-1">수용인원</span>
      <input name="capacity" type="number" min="1" class="w-full rounded border px-2 py-1.5 text-sm" />
    </label>
    <button type="submit" class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">추가</button>
  </form>
{/if}

<div class="rounded-lg border bg-white overflow-hidden">
  <table class="w-full text-sm">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-4 py-2 text-left font-medium text-gray-500">이름</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">위치</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">수용인원</th>
        <th class="px-4 py-2 text-left font-medium text-gray-500">상태</th>
        <th class="px-4 py-2 text-right font-medium text-gray-500">작업</th>
      </tr>
    </thead>
    <tbody>
      {#each data.rooms as room (room.id)}
        <tr class="border-t">
          {#if editingId === room.id}
            <td colspan="5" class="px-4 py-2">
              <form method="POST" action="?/update" use:enhance={() => { return async ({ update }) => { editingId = null; await update(); }; }} class="flex gap-3 items-end">
                <input type="hidden" name="id" value={room.id} />
                <input name="name" value={room.name} required class="flex-1 rounded border px-2 py-1.5 text-sm" />
                <input name="location" value={room.location ?? ''} class="flex-1 rounded border px-2 py-1.5 text-sm" />
                <input name="capacity" type="number" value={room.capacity ?? ''} class="w-20 rounded border px-2 py-1.5 text-sm" />
                <label class="flex items-center gap-1 text-xs">
                  <input type="checkbox" name="is_active" value="true" checked={room.is_active} />
                  활성
                </label>
                <button type="submit" class="rounded bg-blue-600 px-2 py-1 text-xs text-white">저장</button>
                <button type="button" class="text-xs text-gray-500" onclick={() => (editingId = null)}>취소</button>
              </form>
            </td>
          {:else}
            <td class="px-4 py-2">{room.name}</td>
            <td class="px-4 py-2 text-gray-600">{room.location ?? '-'}</td>
            <td class="px-4 py-2 text-gray-600">{room.capacity ?? '-'}</td>
            <td class="px-4 py-2">
              <span class="text-xs px-1.5 py-0.5 rounded {room.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}">
                {room.is_active ? '활성' : '비활성'}
              </span>
            </td>
            <td class="px-4 py-2 text-right space-x-2">
              <button type="button" class="text-xs text-blue-600 hover:underline" onclick={() => (editingId = room.id)}>수정</button>
              <form method="POST" action="?/delete" use:enhance class="inline">
                <input type="hidden" name="id" value={room.id} />
                <button type="submit" class="text-xs text-red-600 hover:underline">삭제</button>
              </form>
            </td>
          {/if}
        </tr>
      {:else}
        <tr>
          <td colspan="5" class="px-4 py-8 text-center text-gray-400">등록된 회의실이 없습니다</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
