<script lang="ts">
  /**
   * ConditionalsEditor — FormBuilder 내 조건부 표시 규칙 편집기 (v2.1 M6).
   * ConditionalRule[] 을 시각적으로 편집: if field op value → show/hide fields.
   */
  import type { ConditionalRule, FormField } from '$lib/types/approval';

  type Props = {
    fields: FormField[];
    conditionals: ConditionalRule[];
    onChange: (next: ConditionalRule[]) => void;
  };

  let { fields, conditionals, onChange }: Props = $props();

  function addRule() {
    onChange([...conditionals, {
      if: { fieldId: '', operator: 'eq', value: '' },
      show: [],
      hide: []
    }]);
  }

  function removeRule(idx: number) {
    onChange(conditionals.filter((_, i) => i !== idx));
  }

  function updateIf(idx: number, partial: Partial<ConditionalRule['if']>) {
    const next = conditionals.map((r, i) =>
      i === idx ? { ...r, if: { ...r.if, ...partial } } : r
    );
    onChange(next);
  }

  function toggleFieldInList(idx: number, list: 'show' | 'hide', fieldId: string, checked: boolean) {
    const next = conditionals.map((r, i) => {
      if (i !== idx) return r;
      const current = r[list] ?? [];
      const updated = checked
        ? [...current, fieldId]
        : current.filter((id) => id !== fieldId);
      return { ...r, [list]: updated };
    });
    onChange(next);
  }
</script>

<div class="space-y-3">
  <div class="flex items-center justify-between">
    <h3 class="text-sm font-semibold">조건부 표시 규칙</h3>
    <button type="button" onclick={addRule} class="text-xs text-blue-600 hover:underline">+ 규칙 추가</button>
  </div>

  {#each conditionals as rule, idx (idx)}
    <div class="rounded border bg-gray-50 p-3 space-y-2">
      <!-- IF 조건 -->
      <div class="flex flex-wrap items-center gap-1 text-sm">
        <span class="font-medium text-gray-600">IF</span>
        <select
          value={rule.if.fieldId}
          onchange={(e) => updateIf(idx, { fieldId: e.currentTarget.value })}
          class="rounded border px-2 py-0.5 text-sm"
        >
          <option value="">필드 선택</option>
          {#each fields as f (f.id)}
            <option value={f.id}>{f.label}</option>
          {/each}
        </select>
        <select
          value={rule.if.operator}
          onchange={(e) => updateIf(idx, { operator: e.currentTarget.value as ConditionalRule['if']['operator'] })}
          class="rounded border px-2 py-0.5 text-sm"
        >
          <option value="eq">=</option>
          <option value="neq">≠</option>
          <option value="gte">≥</option>
          <option value="lte">≤</option>
          <option value="contains">포함</option>
        </select>
        <input
          type="text"
          value={String(rule.if.value ?? '')}
          onchange={(e) => updateIf(idx, { value: e.currentTarget.value })}
          class="w-24 rounded border px-2 py-0.5 text-sm"
          placeholder="값"
        />
        <button type="button" onclick={() => removeRule(idx)} class="ml-auto text-red-400 hover:text-red-600">×</button>
      </div>

      <!-- SHOW -->
      <div class="flex flex-wrap gap-1.5 text-xs">
        <span class="font-medium text-green-600">SHOW:</span>
        {#each fields as f (f.id)}
          <label class="flex items-center gap-0.5">
            <input
              type="checkbox"
              checked={rule.show?.includes(f.id) ?? false}
              onchange={(e) => toggleFieldInList(idx, 'show', f.id, e.currentTarget.checked)}
            />
            {f.label}
          </label>
        {/each}
      </div>

      <!-- HIDE -->
      <div class="flex flex-wrap gap-1.5 text-xs">
        <span class="font-medium text-red-600">HIDE:</span>
        {#each fields as f (f.id)}
          <label class="flex items-center gap-0.5">
            <input
              type="checkbox"
              checked={rule.hide?.includes(f.id) ?? false}
              onchange={(e) => toggleFieldInList(idx, 'hide', f.id, e.currentTarget.checked)}
            />
            {f.label}
          </label>
        {/each}
      </div>
    </div>
  {/each}

  {#if conditionals.length === 0}
    <p class="text-xs text-gray-400">조건부 규칙이 없습니다. 모든 필드가 항상 표시됩니다.</p>
  {/if}
</div>
