<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();

  let showNew = $state(false);
  let newLineTemplate = $state('[{"role": "team_lead", "stepType": "approval"}]');
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h2 class="text-lg font-semibold">결재선 규칙</h2>
    <button
      type="button"
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
      onclick={() => (showNew = !showNew)}
    >
      + 새 규칙
    </button>
  </div>

  {#if form?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.actionError}</p>
  {/if}
  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">저장되었습니다.</p>
  {/if}

  {#if showNew}
    <form method="POST" action="?/create" use:enhance class="space-y-3 rounded-lg border bg-white p-4">
      <label class="block">
        <span class="text-sm font-medium">규칙 이름</span>
        <input type="text" name="name" required class="mt-1 block w-full rounded border px-3 py-2 text-sm" placeholder="예: 기본 결재선" />
      </label>
      <label class="block">
        <span class="text-sm font-medium">양식 (비워두면 모든 양식)</span>
        <select name="form_id" class="mt-1 block w-full rounded border px-3 py-2 text-sm">
          <option value="">전체 양식</option>
          {#each data.availableForms as f (f.id)}
            <option value={f.id}>{f.name} ({f.code})</option>
          {/each}
        </select>
      </label>
      <label class="block">
        <span class="text-sm font-medium">우선순위 (낮을수록 우선)</span>
        <input type="number" name="priority" value="100" min="1" class="mt-1 block w-full rounded border px-3 py-2 text-sm" />
      </label>
      <label class="block">
        <span class="text-sm font-medium">결재선 템플릿 (JSON)</span>
        <textarea name="line_template_json" rows="4" class="mt-1 block w-full rounded border px-3 py-2 font-mono text-sm" bind:value={newLineTemplate}></textarea>
        <p class="mt-1 text-xs text-gray-400">role: "team_lead" | "department_head" | "ceo" | UUID</p>
      </label>
      <div class="flex gap-2">
        <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white">생성</button>
        <button type="button" class="rounded border px-4 py-2 text-sm" onclick={() => (showNew = false)}>취소</button>
      </div>
    </form>
  {/if}

  {#if data.rules.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      결재선 규칙이 없습니다. 규칙을 추가하면 기안 시 자동으로 결재선이 구성됩니다.
    </div>
  {:else}
    <ul class="space-y-2">
      {#each data.rules as rule (rule.id)}
        <li class="flex items-center gap-3 rounded border bg-white px-4 py-3">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="font-medium">{rule.name}</span>
              <span class="text-xs text-gray-400">우선순위: {rule.priority}</span>
              {#if !rule.is_active}
                <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-500">비활성</span>
              {/if}
            </div>
            <p class="mt-1 truncate font-mono text-xs text-gray-500">
              {JSON.stringify(rule.line_template_json)}
            </p>
          </div>

          <form method="POST" action="?/toggle" use:enhance>
            <input type="hidden" name="id" value={rule.id} />
            <input type="hidden" name="active" value={!rule.is_active} />
            <button type="submit" class="rounded px-2 py-1 text-xs" class:bg-green-100={rule.is_active} class:text-green-700={rule.is_active} class:bg-gray-100={!rule.is_active}>
              {rule.is_active ? '활성' : '비활성'}
            </button>
          </form>

          <form method="POST" action="?/delete" use:enhance>
            <input type="hidden" name="id" value={rule.id} />
            <button type="submit" class="text-xs text-red-500 hover:underline" onclick={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}>삭제</button>
          </form>
        </li>
      {/each}
    </ul>
  {/if}
</div>
