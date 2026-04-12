<script lang="ts">
  import { untrack } from 'svelte';
  import { dndzone } from 'svelte-dnd-action';
  import FieldPalette from './FieldPalette.svelte';
  import FieldEditor from './FieldEditor.svelte';
  import FormRenderer from './FormRenderer.svelte';
  import ConditionalsEditor from './ConditionalsEditor.svelte';
  import type { ConditionalRule, FormField, FormFieldType, FormSchema } from '$lib/types/approval';

  type Props = {
    initialSchema: FormSchema;
    tenantId: string;
    onSave: (schema: FormSchema) => void;
  };

  let { initialSchema, tenantId, onSave }: Props = $props();

  let fields = $state<(FormField & { dndId: string })[]>(
    initialSchema.fields.map((f) => ({ ...f, dndId: crypto.randomUUID() }))
  );
  let selectedIndex = $state<number | null>(null);
  let previewMode = $state(false);
  let conditionals = $state<ConditionalRule[]>(untrack(() => [...(initialSchema.conditionals ?? [])]));

  const schema = $derived<FormSchema>({
    version: 1,
    fields: fields.map(({ dndId, ...rest }) => rest as FormField),
    conditionals: conditionals.length > 0 ? conditionals : undefined
  });

  const previewValue = $derived<Record<string, unknown>>(
    Object.fromEntries(schema.fields.map((f) => [f.id, '']))
  );

  function addField(type: FormFieldType) {
    const id = `field_${Date.now()}`;
    const base = { id, label: '새 필드', type, required: false, dndId: crypto.randomUUID() };

    let newField: FormField & { dndId: string };
    if (type === 'select') {
      newField = { ...base, type: 'select', options: [{ value: '옵션 1', label: '옵션 1' }, { value: '옵션 2', label: '옵션 2' }] } as FormField & { dndId: string };
    } else {
      newField = base as FormField & { dndId: string };
    }

    fields = [...fields, newField];
    selectedIndex = fields.length; // will be length after push
  }

  function updateField(index: number, updated: FormField) {
    fields[index] = { ...updated, dndId: fields[index].dndId };
  }

  function deleteField(index: number) {
    fields = fields.filter((_, i) => i !== index);
    selectedIndex = null;
  }

  function handleDndConsider(e: CustomEvent<{ items: typeof fields }>) {
    fields = e.detail.items;
  }

  function handleDndFinalize(e: CustomEvent<{ items: typeof fields }>) {
    fields = e.detail.items;
  }

  function save() {
    onSave(schema);
  }
</script>

<div class="flex h-full gap-4">
  <!-- Left: Field Palette -->
  <div class="w-48 flex-shrink-0 rounded-lg border bg-gray-50 p-3">
    <FieldPalette onAddField={addField} />
  </div>

  <!-- Center: Canvas -->
  <div class="flex-1 space-y-3">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold">양식 빌더</h2>
      <div class="flex gap-2">
        <button
          type="button"
          class="rounded border px-3 py-1 text-sm"
          class:bg-blue-50={previewMode}
          onclick={() => (previewMode = !previewMode)}
        >
          {previewMode ? '편집' : '미리보기'}
        </button>
        <button
          type="button"
          class="rounded bg-blue-600 px-4 py-1 text-sm text-white hover:bg-blue-700"
          onclick={save}
        >
          저장
        </button>
      </div>
    </div>

    {#if previewMode}
      <div class="rounded-lg border bg-white p-6">
        <FormRenderer schema={schema} {tenantId} value={previewValue} readonly={false} onChange={() => {}} />
      </div>
    {:else}
      <div
        class="min-h-64 space-y-2 rounded-lg border-2 border-dashed border-gray-300 p-4"
        use:dndzone={{ items: fields, flipDurationMs: 200 }}
        onconsider={handleDndConsider}
        onfinalize={handleDndFinalize}
      >
        {#each fields as field, i (field.dndId)}
          <button
            type="button"
            class="flex w-full items-center gap-3 rounded border bg-white px-4 py-3 text-left text-sm shadow-sm transition hover:shadow"
            class:ring-2={selectedIndex === i}
            class:ring-blue-500={selectedIndex === i}
            onclick={() => (selectedIndex = i)}
          >
            <span class="cursor-grab text-gray-400">⠿</span>
            <span class="flex-1 font-medium">{field.label}</span>
            <span class="text-xs text-gray-400">{field.type}</span>
            {#if field.required}
              <span class="text-red-500">*</span>
            {/if}
          </button>
        {/each}

        {#if fields.length === 0}
          <p class="py-12 text-center text-sm text-gray-400">
            왼쪽에서 필드를 추가하거나 드래그하세요
          </p>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Right: Field Editor + Conditionals -->
  <div class="w-64 flex-shrink-0 space-y-4">
    {#if selectedIndex !== null && fields[selectedIndex]}
      <FieldEditor
        field={fields[selectedIndex]}
        onUpdate={(f) => updateField(selectedIndex!, f)}
        onDelete={() => deleteField(selectedIndex!)}
      />
    {:else}
      <div class="rounded-lg border bg-gray-50 p-4 text-center text-sm text-gray-400">
        필드를 선택하면 설정을 편집할 수 있습니다
      </div>
    {/if}

    <!-- v2.1 M6: 조건부 표시 규칙 -->
    <div class="rounded-lg border bg-white p-3">
      <ConditionalsEditor
        fields={schema.fields}
        {conditionals}
        onChange={(next) => conditionals = next}
      />
    </div>
  </div>
</div>
