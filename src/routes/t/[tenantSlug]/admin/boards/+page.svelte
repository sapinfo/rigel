<script lang="ts">
  import { enhance } from '$app/forms';
  let { data, form } = $props();

  let showCreate = $state(false);
  let newName = $state('');
  let newDesc = $state('');
  let newType = $state('general');
  let newDeptId = $state('');
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-xl font-bold">게시판 관리</h1>
    <button
      type="button"
      onclick={() => (showCreate = !showCreate)}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      + 게시판 추가
    </button>
  </div>

  {#if form?.error}
    <p class="rounded bg-red-50 p-3 text-sm text-red-600">{form.error}</p>
  {/if}

  <!-- Create form -->
  {#if showCreate}
    <form method="POST" action="?/create" use:enhance class="rounded-lg border bg-white p-4 space-y-3">
      <label class="block">
        <span class="text-sm font-medium">게시판 이름</span>
        <input name="name" bind:value={newName} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
      </label>
      <label class="block">
        <span class="text-sm font-medium">설명</span>
        <input name="description" bind:value={newDesc} class="mt-1 block w-full rounded border px-3 py-2 text-sm" />
      </label>
      <label class="block">
        <span class="text-sm font-medium">유형</span>
        <select name="board_type" bind:value={newType} class="mt-1 block w-full rounded border px-3 py-2 text-sm">
          <option value="general">전사</option>
          <option value="department">부서</option>
        </select>
      </label>
      {#if newType === 'department'}
        <label class="block">
          <span class="text-sm font-medium">부서</span>
          <select name="department_id" bind:value={newDeptId} class="mt-1 block w-full rounded border px-3 py-2 text-sm">
            <option value="">선택</option>
            {#each data.departments as dept (dept.id)}
              <option value={dept.id}>{dept.name}</option>
            {/each}
          </select>
        </label>
      {/if}
      <div class="flex gap-2">
        <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">생성</button>
        <button type="button" onclick={() => (showCreate = false)} class="rounded border px-4 py-2 text-sm">취소</button>
      </div>
    </form>
  {/if}

  <!-- Board list -->
  {#if data.boards.length === 0}
    <p class="text-sm text-gray-500">게시판이 없습니다.</p>
  {:else}
    <div class="overflow-x-auto rounded-lg border bg-white">
      <table class="w-full text-sm">
        <thead class="border-b bg-gray-50 text-left text-xs text-gray-500">
          <tr>
            <th class="px-4 py-2">이름</th>
            <th class="px-4 py-2">유형</th>
            <th class="px-4 py-2">상태</th>
            <th class="px-4 py-2">작업</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          {#each data.boards as board (board.id)}
            <tr>
              <td class="px-4 py-2.5">
                <span class="font-medium">{board.name}</span>
                {#if board.description}
                  <span class="ml-2 text-xs text-gray-400">{board.description}</span>
                {/if}
              </td>
              <td class="px-4 py-2.5">
                {#if board.board_type === 'department'}
                  <span class="text-xs rounded bg-blue-100 px-1.5 py-0.5 text-blue-700">부서</span>
                {:else}
                  <span class="text-xs rounded bg-gray-100 px-1.5 py-0.5 text-gray-600">전사</span>
                {/if}
              </td>
              <td class="px-4 py-2.5">
                <form method="POST" action="?/update" use:enhance class="inline">
                  <input type="hidden" name="id" value={board.id} />
                  <input type="hidden" name="name" value={board.name} />
                  <input type="hidden" name="is_active" value={board.is_active ? 'false' : 'true'} />
                  <button type="submit" class="text-xs {board.is_active ? 'text-green-600' : 'text-gray-400'} hover:underline">
                    {board.is_active ? '활성' : '비활성'}
                  </button>
                </form>
              </td>
              <td class="px-4 py-2.5">
                <form method="POST" action="?/delete" use:enhance
                  onsubmit={(e) => { if (!confirm(`"${board.name}" 게시판을 삭제하시겠습니까?`)) e.preventDefault(); }}
                  class="inline"
                >
                  <input type="hidden" name="id" value={board.id} />
                  <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
                </form>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
