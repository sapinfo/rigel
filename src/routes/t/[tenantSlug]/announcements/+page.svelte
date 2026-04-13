<script lang="ts">
  let { data } = $props();
  const slug = data.currentTenant.slug;

  function formatDate(iso: string) {
    return new Date(iso).toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' });
  }
</script>

<div class="space-y-4">
  <h1 class="text-xl font-bold">공지사항</h1>

  {#if data.announcements.length === 0}
    <p class="text-sm text-gray-500">공지사항이 없습니다.</p>
  {:else}
    <div class="space-y-2">
      {#each data.announcements as ann (ann.id)}
        <a
          href="/t/{slug}/announcements/{ann.id}"
          class="flex items-center justify-between rounded-lg border bg-white px-4 py-3 transition hover:shadow {ann.require_read_confirm && !ann.is_read ? 'border-l-4 border-l-red-500' : ''}"
        >
          <div class="flex items-center gap-2">
            {#if ann.require_read_confirm && !ann.is_read}
              <span class="text-xs rounded bg-red-100 px-1.5 py-0.5 text-red-600 font-medium">필독</span>
            {/if}
            {#if ann.is_popup}
              <span class="text-xs rounded bg-yellow-100 px-1.5 py-0.5 text-yellow-700">팝업</span>
            {/if}
            <span class="font-medium">{ann.title}</span>
          </div>
          <div class="flex items-center gap-3 text-xs text-gray-400">
            <span>{ann.author_name}</span>
            <span>{formatDate(ann.published_at)}</span>
            {#if ann.is_read}
              <span class="text-green-500">읽음</span>
            {/if}
          </div>
        </a>
      {/each}
    </div>
  {/if}
</div>
