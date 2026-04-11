<script lang="ts">
  import type { FormField } from '$lib/types/approval';
  import type { UploadedAttachment } from '$lib/client/uploadAttachment';
  import AttachmentInput from './AttachmentInput.svelte';

  type Props = {
    field: FormField;
    tenantId: string;
    value: unknown;
    error?: string;
    readonly?: boolean;
    onChange: (next: unknown) => void;
  };

  let { field, tenantId, value, error, readonly = false, onChange }: Props = $props();
</script>

<label class="flex flex-col gap-1">
  <span class="text-sm font-medium">
    {field.label}
    {#if field.required}<span class="text-red-500">*</span>{/if}
  </span>

  {#if field.type === 'text'}
    <input
      type="text"
      class="rounded border px-3 py-2"
      class:border-red-500={error}
      value={(value as string | undefined) ?? ''}
      placeholder={field.placeholder}
      maxlength={field.maxLength}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    />
  {:else if field.type === 'textarea'}
    <textarea
      class="rounded border px-3 py-2 min-h-24"
      class:border-red-500={error}
      value={(value as string | undefined) ?? ''}
      placeholder={field.placeholder}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    ></textarea>
  {:else if field.type === 'number'}
    <div class="flex items-center gap-2">
      <input
        type="number"
        class="flex-1 rounded border px-3 py-2"
        class:border-red-500={error}
        value={(value as number | undefined) ?? ''}
        min={field.min}
        max={field.max}
        step={field.step}
        disabled={readonly}
        oninput={(e) => onChange(e.currentTarget.value === '' ? null : Number(e.currentTarget.value))}
      />
      {#if field.unit}<span class="text-sm text-gray-500">{field.unit}</span>{/if}
    </div>
  {:else if field.type === 'date'}
    <input
      type="date"
      class="rounded border px-3 py-2"
      class:border-red-500={error}
      value={(value as string | undefined) ?? ''}
      min={field.min}
      max={field.max}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    />
  {:else if field.type === 'date-range'}
    {@const range = (value as { start?: string; end?: string } | undefined) ?? {}}
    <div class="flex gap-2">
      <input
        type="date"
        class="rounded border px-3 py-2"
        value={range.start ?? ''}
        disabled={readonly}
        oninput={(e) => onChange({ ...range, start: e.currentTarget.value })}
      />
      <span class="self-center">~</span>
      <input
        type="date"
        class="rounded border px-3 py-2"
        value={range.end ?? ''}
        disabled={readonly}
        oninput={(e) => onChange({ ...range, end: e.currentTarget.value })}
      />
    </div>
  {:else if field.type === 'select'}
    <select
      class="rounded border px-3 py-2"
      class:border-red-500={error}
      value={(value as string | undefined) ?? ''}
      disabled={readonly}
      onchange={(e) => onChange(e.currentTarget.value)}
    >
      <option value="">선택하세요</option>
      {#each field.options as opt}
        <option value={opt.value}>{opt.label}</option>
      {/each}
    </select>
  {:else if field.type === 'attachment'}
    <AttachmentInput
      {field}
      {tenantId}
      value={(value as UploadedAttachment[] | undefined) ?? []}
      {readonly}
      {onChange}
    />
  {/if}

  {#if error}<span class="text-xs text-red-500">{error}</span>{/if}
  {#if field.help}<span class="text-xs text-gray-500">{field.help}</span>{/if}
</label>
