<script lang="ts">
  import { enhance } from '$app/forms';
  import RichEditor from '$lib/components/RichEditor.svelte';
  import CommentSection from '$lib/components/CommentSection.svelte';

  let { data, form } = $props();
  const slug = data.currentTenant.slug;

  function formatDate(iso: string) {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }

  const contentHtml = typeof data.post.content === 'object' && data.post.content !== null
    ? (data.post.content as Record<string, string>).html ?? ''
    : '';
</script>

<div class="space-y-6">
  <!-- Post header -->
  <div class="rounded-lg border bg-white p-5">
    <div class="flex items-start justify-between">
      <h1 class="text-xl font-bold">
        {#if data.post.is_pinned}
          <span class="mr-1 text-sm text-red-600">[공지]</span>
        {/if}
        {data.post.title}
      </h1>

      {#if data.canEdit}
        <div class="flex gap-1">
          {#if data.isAdmin}
            <form method="POST" action="?/togglePin" use:enhance>
              <input type="hidden" name="pin" value={data.post.is_pinned ? 'false' : 'true'} />
              <button type="submit" class="rounded border px-2 py-1 text-xs hover:bg-gray-50">
                {data.post.is_pinned ? '고정 해제' : '상단 고정'}
              </button>
            </form>
          {/if}
          <form method="POST" action="?/deletePost" use:enhance
            onsubmit={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}>
            <button type="submit" class="rounded border px-2 py-1 text-xs text-red-600 hover:bg-red-50">삭제</button>
          </form>
        </div>
      {/if}
    </div>
    <div class="mt-2 flex gap-3 text-xs text-gray-500">
      <span>{data.post.author_name}</span>
      <span>{formatDate(data.post.created_at)}</span>
      <span>조회 {data.post.view_count}</span>
    </div>

    <div class="mt-4 border-t pt-4">
      <RichEditor value={contentHtml} readonly={true} onChange={() => {}} />
    </div>
  </div>

  <!-- Comments -->
  <CommentSection
    comments={data.comments}
    currentUserId={data.currentUserId}
    isAdmin={data.isAdmin}
    error={form?.error ?? null}
  />

  <a href="/t/{slug}/boards/{data.post.board_id}" class="text-sm text-gray-500 hover:underline">&larr; 목록으로</a>
</div>
