<script lang="ts">
  type Attachment = {
    id: string;
    file_name: string;
    mime: string;
    size: number;
    storage_path: string;
  };

  type Props = {
    attachments: Attachment[];
    downloadUrls: Record<string, string>;
  };

  let { attachments, downloadUrls }: Props = $props();

  function humanSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  }
</script>

{#if attachments.length > 0}
  <section>
    <h3 class="mb-2 text-sm font-semibold text-gray-700">첨부파일</h3>
    <ul class="flex flex-col gap-1">
      {#each attachments as att (att.id)}
        {@const url = downloadUrls[att.storage_path]}
        <li>
          {#if url}
            <a
              href={url}
              class="flex items-center gap-2 rounded border bg-white px-3 py-2 text-sm hover:bg-gray-50"
              download={att.file_name}
            >
              <span class="flex-1 truncate">{att.file_name}</span>
              <span class="shrink-0 text-xs text-gray-500">{humanSize(att.size)}</span>
              <span class="shrink-0 text-xs text-blue-600">다운로드</span>
            </a>
          {:else}
            <div class="flex items-center gap-2 rounded border bg-gray-50 px-3 py-2 text-sm text-gray-400">
              <span class="flex-1 truncate">{att.file_name}</span>
              <span class="shrink-0 text-xs">접근 불가</span>
            </div>
          {/if}
        </li>
      {/each}
    </ul>
  </section>
{/if}
