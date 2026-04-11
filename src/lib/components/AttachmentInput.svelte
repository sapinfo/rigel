<script lang="ts">
  import type { AttachmentField } from '$lib/types/approval';
  import { uploadAttachment, type UploadedAttachment } from '$lib/client/uploadAttachment';

  type Props = {
    field: AttachmentField;
    tenantId: string;
    value: UploadedAttachment[];
    readonly?: boolean;
    onChange: (next: UploadedAttachment[]) => void;
  };

  let { field, tenantId, value = [], readonly = false, onChange }: Props = $props();

  let uploading = $state(false);
  let errorMsg = $state<string | null>(null);
  let fileInput = $state<HTMLInputElement | null>(null);

  async function handleFiles(fileList: FileList | null) {
    if (!fileList || fileList.length === 0) return;
    errorMsg = null;

    const maxFiles = field.maxFiles ?? 10;
    if (value.length + fileList.length > maxFiles) {
      errorMsg = `최대 ${maxFiles}개 파일까지 업로드 가능`;
      return;
    }

    const maxSize = field.maxSizeBytes ?? 10 * 1024 * 1024;
    for (const f of fileList) {
      if (f.size > maxSize) {
        errorMsg = `${f.name} - 파일 크기 초과 (최대 ${Math.round(maxSize / 1024 / 1024)}MB)`;
        return;
      }
    }

    uploading = true;
    try {
      const uploaded: UploadedAttachment[] = [];
      for (const f of fileList) {
        uploaded.push(await uploadAttachment(tenantId, f));
      }
      onChange([...value, ...uploaded]);
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : '업로드 실패';
    } finally {
      uploading = false;
      if (fileInput) fileInput.value = '';
    }
  }

  function removeAt(index: number) {
    onChange(value.filter((_, i) => i !== index));
  }

  function humanSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  }
</script>

<div class="flex flex-col gap-2">
  {#if !readonly}
    <label class="inline-flex items-center gap-2 text-sm">
      <input
        bind:this={fileInput}
        type="file"
        multiple
        accept={field.accept}
        disabled={uploading}
        onchange={(e) => handleFiles(e.currentTarget.files)}
        class="block text-sm"
      />
      {#if uploading}<span class="text-gray-500">업로드 중…</span>{/if}
    </label>
  {/if}

  {#if errorMsg}
    <p class="text-xs text-red-600">{errorMsg}</p>
  {/if}

  {#if value.length > 0}
    <ul class="flex flex-col gap-1">
      {#each value as att, i (att.id)}
        <li class="flex items-center gap-2 rounded border bg-white px-3 py-2 text-sm">
          <span class="flex-1 truncate">{att.fileName}</span>
          <span class="text-xs text-gray-500">{humanSize(att.size)}</span>
          {#if !readonly}
            <button
              type="button"
              class="text-xs text-red-500"
              onclick={() => removeAt(i)}
            >
              제거
            </button>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</div>
