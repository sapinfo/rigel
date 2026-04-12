<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ApprovalLineItem } from '$lib/types/approval';

  let { data, form } = $props();

  let showNew = $state(false);
  let newName = $state('');
  let newFormId = $state('');
  let newPriority = $state(100);
  let newIsDefault = $state(false);
  let newLineJson = $state('[]');

  function lineSummary(line: ApprovalLineItem[]): string {
    return line.map((item) => {
      const m = data.members.find((p) => p.id === item.userId);
      return m?.displayName ?? item.userId.slice(0, 8);
    }).join(' → ');
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">결재선 템플릿</h1>
    <button type="button" onclick={() => showNew = !showNew} class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">+ 새 템플릿</button>
  </div>

  {#if form?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.actionError}</p>
  {/if}
  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">저장되었습니다.</p>
  {/if}

  {#if showNew}
    <form method="POST" action="?/create" class="rounded-lg border bg-white p-4 space-y-3" use:enhance={() => {
      return async ({ update }) => { await update(); showNew = false; newName = ''; newLineJson = '[]'; };
    }}>
      <div class="flex gap-3">
        <label class="flex-1">
          <span class="text-xs text-gray-500">템플릿 이름</span>
          <input type="text" name="name" bind:value={newName} required class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm" />
        </label>
        <label>
          <span class="text-xs text-gray-500">양식</span>
          <select name="formId" bind:value={newFormId} class="mt-0.5 block rounded border px-3 py-1.5 text-sm">
            <option value="">전체</option>
            {#each data.availableForms as f (f.id)}
              <option value={f.id}>{f.name}</option>
            {/each}
          </select>
        </label>
        <label>
          <span class="text-xs text-gray-500">우선순위</span>
          <input type="number" name="priority" bind:value={newPriority} min="1" class="mt-0.5 block w-20 rounded border px-3 py-1.5 text-sm" />
        </label>
      </div>
      <label class="block">
        <span class="text-xs text-gray-500">결재선 (JSON)</span>
        <textarea name="lineJson" bind:value={newLineJson} rows="3" class="mt-0.5 block w-full rounded border px-3 py-2 font-mono text-sm"></textarea>
        <p class="mt-0.5 text-xs text-gray-400">[{`{"userId":"...", "stepType":"approval"}`}]</p>
      </label>
      <label class="flex items-center gap-2">
        <input type="checkbox" name="isDefault" bind:checked={newIsDefault} />
        <span class="text-sm">기본 템플릿으로 설정</span>
      </label>
      <div class="flex gap-2">
        <button type="submit" class="rounded bg-blue-600 px-4 py-1.5 text-sm text-white">생성</button>
        <button type="button" onclick={() => showNew = false} class="rounded border px-4 py-1.5 text-sm">취소</button>
      </div>
    </form>
  {/if}

  {#if data.templates.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      결재선 템플릿이 없습니다. 템플릿을 추가하면 기안 시 추천 결재선으로 표시됩니다.
    </div>
  {:else}
    <ul class="space-y-2">
      {#each data.templates as tpl (tpl.id)}
        <li class="rounded border bg-white px-4 py-3">
          <div class="flex items-center gap-3">
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <span class="font-medium">{tpl.name}</span>
                {#if tpl.isDefault}
                  <span class="rounded bg-blue-100 px-1.5 py-0.5 text-xs text-blue-700">기본</span>
                {/if}
                <span class="text-xs text-gray-400">우선순위: {tpl.priority}</span>
                {#if tpl.formId}
                  {@const formName = data.availableForms.find(f => f.id === tpl.formId)?.name}
                  {#if formName}
                    <span class="text-xs text-gray-400">{formName}</span>
                  {/if}
                {:else}
                  <span class="text-xs text-gray-400">전체 양식</span>
                {/if}
              </div>
              <p class="mt-1 text-xs text-gray-500">{lineSummary(tpl.lineJson)}</p>
            </div>

            <form method="POST" action="?/setDefault" use:enhance>
              <input type="hidden" name="id" value={tpl.id} />
              <button type="submit" class="rounded px-2 py-1 text-xs" class:bg-blue-50={!tpl.isDefault} class:text-blue-600={!tpl.isDefault} class:bg-gray-100={tpl.isDefault}>
                {tpl.isDefault ? '기본' : '기본으로'}
              </button>
            </form>

            <form method="POST" action="?/delete" use:enhance onsubmit={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}>
              <input type="hidden" name="id" value={tpl.id} />
              <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
            </form>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>
