<script lang="ts">
  /**
   * ConditionEditor — 조건(field/operator/value) 편집 UI.
   * M1(규칙 빌더), M6(조건부 필드) 공용.
   */
  type FieldOption = { id: string; label: string };
  type ConditionValue = { field: string; operator: string; value: string };

  type Props = {
    fields: FieldOption[];
    condition: ConditionValue;
    onChange: (next: ConditionValue) => void;
  };

  let { fields, condition, onChange }: Props = $props();

  function update(partial: Partial<ConditionValue>) {
    onChange({ ...condition, ...partial });
  }
</script>

<div class="flex flex-wrap gap-2">
  <label class="flex items-center gap-1">
    <span class="text-xs text-gray-500">필드</span>
    <select
      value={condition.field}
      onchange={(e) => update({ field: e.currentTarget.value })}
      class="rounded border px-2 py-1 text-sm"
    >
      <option value="">선택</option>
      {#each fields as f (f.id)}
        <option value={f.id}>{f.label}</option>
      {/each}
    </select>
  </label>
  <label class="flex items-center gap-1">
    <span class="text-xs text-gray-500">연산자</span>
    <select
      value={condition.operator}
      onchange={(e) => update({ operator: e.currentTarget.value })}
      class="rounded border px-2 py-1 text-sm"
    >
      <option value="eq">같음 (=)</option>
      <option value="neq">다름 (≠)</option>
      <option value="gte">이상 (≥)</option>
      <option value="lte">이하 (≤)</option>
      <option value="contains">포함</option>
    </select>
  </label>
  <label class="flex items-center gap-1">
    <span class="text-xs text-gray-500">값</span>
    <input
      type="text"
      value={condition.value}
      onchange={(e) => update({ value: e.currentTarget.value })}
      class="w-32 rounded border px-2 py-1 text-sm"
      placeholder="비교 값"
    />
  </label>
</div>
