<script lang="ts">
  import type { FormField } from '$lib/types/approval';

  type Props = {
    field: FormField;
    onUpdate: (field: FormField) => void;
    onDelete: () => void;
  };

  let { field, onUpdate, onDelete }: Props = $props();

  function update(patch: Partial<FormField>) {
    onUpdate({ ...field, ...patch } as FormField);
  }
</script>

<div class="space-y-3 rounded-lg border bg-white p-4">
  <div class="flex items-center justify-between">
    <h4 class="text-sm font-semibold">필드 설정</h4>
    <button type="button" class="text-xs text-red-500 hover:underline" onclick={onDelete}>
      삭제
    </button>
  </div>

  <label class="block">
    <span class="text-xs text-gray-500">라벨</span>
    <input
      type="text"
      value={field.label}
      oninput={(e) => update({ label: (e.currentTarget as HTMLInputElement).value })}
      class="mt-1 block w-full rounded border px-2 py-1 text-sm"
    />
  </label>

  <label class="block">
    <span class="text-xs text-gray-500">필드 ID</span>
    <input
      type="text"
      value={field.id}
      oninput={(e) => update({ id: (e.currentTarget as HTMLInputElement).value })}
      class="mt-1 block w-full rounded border px-2 py-1 text-sm font-mono"
    />
  </label>

  <label class="flex items-center gap-2">
    <input
      type="checkbox"
      checked={field.required ?? false}
      onchange={(e) => update({ required: (e.currentTarget as HTMLInputElement).checked })}
    />
    <span class="text-sm">필수 항목</span>
  </label>

  {#if field.type === 'select' && 'options' in field}
    <label class="block">
      <span class="text-xs text-gray-500">옵션 (줄바꿈으로 구분)</span>
      <textarea
        value={(field as unknown as { options: { value: string; label: string }[] }).options?.map((o) => o.label).join('\n') ?? ''}
        oninput={(e) => {
          const opts = (e.currentTarget as HTMLTextAreaElement).value.split('\n').filter(Boolean).map((s) => ({ value: s, label: s }));
          update({ options: opts } as unknown as Partial<FormField>);
        }}
        class="mt-1 block w-full rounded border px-2 py-1 text-sm"
        rows="3"
      ></textarea>
    </label>
  {/if}

  <p class="text-xs text-gray-400">타입: {field.type}</p>
</div>
