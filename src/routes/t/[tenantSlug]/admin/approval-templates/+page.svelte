<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ApprovalLineItem } from '$lib/types/approval';

  let { data, form } = $props();

  let showNew = $state(false);
  let editingId = $state<string | null>(null);

  // 새 템플릿 state
  let newName = $state('');
  let newFormId = $state('');
  let newPriority = $state(100);
  let newIsDefault = $state(false);
  let newSteps = $state<{ userId: string; stepType: string }[]>([]);

  // 편집 state
  let editName = $state('');
  let editFormId = $state('');
  let editPriority = $state(100);
  let editIsDefault = $state(false);
  let editSteps = $state<{ userId: string; stepType: string }[]>([]);

  function getMemberName(userId: string): string {
    return data.members.find((m) => m.id === userId)?.displayName ?? userId.slice(0, 8);
  }

  function lineSummary(line: ApprovalLineItem[]): string {
    return line.map((item) => getMemberName(item.userId)).join(' → ');
  }

  function stepsToJson(steps: { userId: string; stepType: string }[]): string {
    return JSON.stringify(steps.map((s) => ({ userId: s.userId, stepType: s.stepType })));
  }

  function openEdit(tpl: typeof data.templates[0]) {
    editingId = tpl.id;
    editName = tpl.name;
    editFormId = tpl.formId ?? '';
    editPriority = tpl.priority;
    editIsDefault = tpl.isDefault;
    editSteps = tpl.lineJson.map((s) => ({ userId: s.userId, stepType: s.stepType }));
  }

  // hidden form refs
  let createFormEl = $state<HTMLFormElement | null>(null);
  let updateFormEl = $state<HTMLFormElement | null>(null);
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">결재선 템플릿</h1>
    {#if !showNew}
      <button type="button" onclick={() => { showNew = true; newSteps = []; newName = ''; }} class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">+ 새 템플릿</button>
    {/if}
  </div>

  {#if form?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.actionError}</p>
  {/if}
  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">저장되었습니다.</p>
  {/if}

  <!-- 숨겨진 생성 폼 -->
  <form bind:this={createFormEl} method="POST" action="?/create" class="hidden" use:enhance={() => {
    return async ({ update }) => { await update(); showNew = false; };
  }}>
    <input type="hidden" name="name" value={newName} />
    <input type="hidden" name="formId" value={newFormId} />
    <input type="hidden" name="priority" value={newPriority} />
    <input type="hidden" name="isDefault" value={String(newIsDefault)} />
    <input type="hidden" name="lineJson" value={stepsToJson(newSteps)} />
  </form>

  <!-- 숨겨진 수정 폼 -->
  <form bind:this={updateFormEl} method="POST" action="?/update" class="hidden" use:enhance={() => {
    return async ({ update }) => { await update(); editingId = null; };
  }}>
    <input type="hidden" name="id" value={editingId ?? ''} />
    <input type="hidden" name="name" value={editName} />
    <input type="hidden" name="formId" value={editFormId} />
    <input type="hidden" name="priority" value={editPriority} />
    <input type="hidden" name="isDefault" value={String(editIsDefault)} />
    <input type="hidden" name="lineJson" value={stepsToJson(editSteps)} />
  </form>

  <!-- 새 템플릿 빌더 -->
  {#if showNew}
    {@render templateEditor(newName, newFormId, newPriority, newIsDefault, newSteps, 'create')}
  {/if}

  <!-- 편집 중인 템플릿 -->
  {#if editingId}
    {@render templateEditor(editName, editFormId, editPriority, editIsDefault, editSteps, 'edit')}
  {/if}

  <!-- 목록 -->
  {#if data.templates.length === 0 && !showNew}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      결재선 템플릿이 없습니다. 템플릿을 추가하면 기안 시 추천 결재선으로 표시됩니다.
    </div>
  {:else}
    <ul class="space-y-2">
      {#each data.templates as tpl (tpl.id)}
        {#if editingId !== tpl.id}
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
                    {@const fn = data.availableForms.find(f => f.id === tpl.formId)}
                    <span class="text-xs text-gray-400">{fn?.name ?? ''}</span>
                  {:else}
                    <span class="text-xs text-gray-400">전체</span>
                  {/if}
                </div>
                <p class="mt-1 text-xs text-gray-500">{lineSummary(tpl.lineJson)}</p>
              </div>
              <button type="button" onclick={() => openEdit(tpl)} class="rounded bg-gray-100 px-2 py-1 text-xs hover:bg-gray-200">편집</button>
              <form method="POST" action="?/setDefault" use:enhance>
                <input type="hidden" name="id" value={tpl.id} />
                <button type="submit" class="rounded px-2 py-1 text-xs {tpl.isDefault ? 'bg-gray-100' : 'bg-blue-50 text-blue-600'}">{tpl.isDefault ? '기본' : '기본으로'}</button>
              </form>
              <form method="POST" action="?/delete" use:enhance onsubmit={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}>
                <input type="hidden" name="id" value={tpl.id} />
                <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
              </form>
            </div>
          </li>
        {/if}
      {/each}
    </ul>
  {/if}
</div>

{#snippet templateEditor(name: string, formId: string, priority: number, isDefault: boolean, steps: { userId: string; stepType: string }[], mode: 'create' | 'edit')}
  <div class="rounded-lg border bg-white p-4 space-y-3">
    <h3 class="text-sm font-semibold">{mode === 'create' ? '새 템플릿' : '템플릿 편집'}</h3>
    <div class="flex gap-3">
      <label class="flex-1">
        <span class="text-xs text-gray-500">이름</span>
        <input type="text" value={name} oninput={(e) => { if (mode === 'create') newName = e.currentTarget.value; else editName = e.currentTarget.value; }} required class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm" />
      </label>
      <label>
        <span class="text-xs text-gray-500">양식</span>
        <select value={formId} onchange={(e) => { if (mode === 'create') newFormId = e.currentTarget.value; else editFormId = e.currentTarget.value; }} class="mt-0.5 block rounded border px-3 py-1.5 text-sm">
          <option value="">전체</option>
          {#each data.availableForms as f (f.id)}
            <option value={f.id}>{f.name}</option>
          {/each}
        </select>
      </label>
      <label>
        <span class="text-xs text-gray-500">우선순위</span>
        <input type="number" value={priority} min="1" oninput={(e) => { if (mode === 'create') newPriority = +e.currentTarget.value; else editPriority = +e.currentTarget.value; }} class="mt-0.5 block w-20 rounded border px-3 py-1.5 text-sm" />
      </label>
    </div>

    <!-- 결재선 구성 (시각적) -->
    <div>
      <span class="text-xs text-gray-500">결재선</span>
      <div class="mt-1 space-y-1">
        {#each steps as step, i (i)}
          <div class="flex items-center gap-2 rounded border bg-gray-50 px-3 py-1.5">
            <span class="text-xs font-semibold text-gray-400">{i + 1}</span>
            <select value={step.userId} onchange={(e) => { step.userId = e.currentTarget.value; }} class="flex-1 rounded border px-2 py-1 text-sm">
              <option value="">멤버 선택</option>
              {#each data.members as m (m.id)}
                <option value={m.id}>{m.displayName} ({m.jobTitle ?? '직급없음'})</option>
              {/each}
            </select>
            <select value={step.stepType} onchange={(e) => { step.stepType = e.currentTarget.value; }} class="rounded border px-2 py-1 text-sm">
              <option value="approval">승인</option>
              <option value="agreement">합의</option>
              <option value="reference">참조</option>
            </select>
            <button type="button" onclick={() => {
              if (mode === 'create') newSteps = steps.filter((_, j) => j !== i);
              else editSteps = steps.filter((_, j) => j !== i);
            }} class="text-red-400 hover:text-red-600">×</button>
          </div>
        {/each}
        <button type="button" onclick={() => {
          const next = [...steps, { userId: '', stepType: 'approval' }];
          if (mode === 'create') newSteps = next; else editSteps = next;
        }} class="w-full rounded border border-dashed py-1.5 text-xs text-gray-400 hover:bg-gray-50">+ 결재자 추가</button>
      </div>
    </div>

    <label class="flex items-center gap-2">
      <input type="checkbox" checked={isDefault} onchange={(e) => { if (mode === 'create') newIsDefault = e.currentTarget.checked; else editIsDefault = e.currentTarget.checked; }} />
      <span class="text-sm">기본 템플릿</span>
    </label>

    <div class="flex gap-2">
      <button type="button" onclick={() => {
        if (mode === 'create') createFormEl?.requestSubmit();
        else updateFormEl?.requestSubmit();
      }} class="rounded bg-blue-600 px-4 py-1.5 text-sm text-white">{mode === 'create' ? '생성' : '저장'}</button>
      <button type="button" onclick={() => { if (mode === 'create') showNew = false; else editingId = null; }} class="rounded border px-4 py-1.5 text-sm">취소</button>
    </div>
  </div>
{/snippet}
