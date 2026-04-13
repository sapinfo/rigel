<script lang="ts">
  import { enhance } from '$app/forms';
  import RichEditor from '$lib/components/RichEditor.svelte';

  let { data } = $props();
  const slug = data.currentTenant.slug;
  const ann = data.announcement;

  const contentHtml = typeof ann.content === 'object' && ann.content !== null
    ? (ann.content as Record<string, string>).html ?? ''
    : '';

  function formatDate(iso: string | null) {
    if (!iso) return '';
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }
</script>

<div class="space-y-4">
  <div class="rounded-lg border bg-white p-5">
    <div class="flex items-center gap-2 mb-1">
      {#if ann.require_read_confirm}
        <span class="text-xs rounded bg-red-100 px-1.5 py-0.5 text-red-600 font-medium">필독</span>
      {/if}
      {#if ann.is_popup}
        <span class="text-xs rounded bg-yellow-100 px-1.5 py-0.5 text-yellow-700">팝업</span>
      {/if}
    </div>
    <h1 class="text-xl font-bold">{ann.title}</h1>
    <div class="mt-2 flex gap-3 text-xs text-gray-500">
      <span>{ann.author_name}</span>
      <span>{formatDate(ann.published_at)}</span>
      {#if ann.expires_at}
        <span>만료: {formatDate(ann.expires_at)}</span>
      {/if}
    </div>

    <div class="mt-4 border-t pt-4">
      <RichEditor value={contentHtml} readonly={true} onChange={() => {}} />
    </div>

    <!-- 읽음 확인 -->
    {#if ann.require_read_confirm && !ann.is_read}
      <div class="mt-4 border-t pt-4">
        <form method="POST" action="?/markRead" use:enhance>
          <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
            읽음 확인
          </button>
        </form>
      </div>
    {:else if ann.is_read}
      <p class="mt-4 text-xs text-green-600">확인 완료</p>
    {/if}
  </div>

  <a href="/t/{slug}/announcements" class="text-sm text-gray-500 hover:underline">&larr; 공지 목록</a>
</div>
