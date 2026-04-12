<script lang="ts">
  import type { FormSchema } from '$lib/types/approval';
  import FormField from './FormField.svelte';

  type Props = {
    schema: FormSchema;
    tenantId: string;
    value: Record<string, unknown>;
    errors?: Record<string, string>;
    readonly?: boolean;
    onChange: (next: Record<string, unknown>) => void;
  };

  let {
    schema,
    tenantId,
    value,
    errors = {},
    readonly = false,
    onChange
  }: Props = $props();

  function updateField(id: string, next: unknown) {
    onChange({ ...value, [id]: next });
  }

  // v2.0: conditional fields — 각 필드의 visible 상태 계산
  const hiddenFieldIds = $derived.by(() => {
    const hidden = new Set<string>();
    if (!schema.conditionals) return hidden;
    for (const rule of schema.conditionals) {
      const fieldVal = String(value[rule.if.fieldId] ?? '');
      const target = String(rule.if.value ?? '');
      let matched = false;
      switch (rule.if.operator) {
        case 'eq': matched = fieldVal === target; break;
        case 'neq': matched = fieldVal !== target; break;
        case 'gte': matched = Number(fieldVal) >= Number(target); break;
        case 'lte': matched = Number(fieldVal) <= Number(target); break;
        case 'contains': matched = fieldVal.toLowerCase().includes(target.toLowerCase()); break;
      }
      if (matched) {
        rule.hide?.forEach((id) => hidden.add(id));
      } else {
        rule.show?.forEach((id) => hidden.add(id));
      }
    }
    return hidden;
  });
</script>

<div class="flex flex-col gap-4">
  {#each schema.fields as field (field.id)}
    {#if !hiddenFieldIds.has(field.id)}
      <FormField
        {field}
        {tenantId}
        value={value[field.id]}
        error={errors[field.id]}
        {readonly}
        onChange={(next) => updateField(field.id, next)}
      />
    {/if}
  {/each}
</div>
