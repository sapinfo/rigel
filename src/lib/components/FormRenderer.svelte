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
</script>

<div class="flex flex-col gap-4">
  {#each schema.fields as field (field.id)}
    <FormField
      {field}
      {tenantId}
      value={value[field.id]}
      error={errors[field.id]}
      {readonly}
      onChange={(next) => updateField(field.id, next)}
    />
  {/each}
</div>
