<script lang="ts">
  import { enhance } from '$app/forms';

  interface Comment {
    id: string;
    author_id: string;
    author_name: string;
    content: string;
    created_at: string;
  }

  interface Props {
    comments: Comment[];
    currentUserId: string;
    isAdmin: boolean;
    error?: string | null;
  }

  let { comments, currentUserId, isAdmin, error = null }: Props = $props();

  let commentText = $state('');

  function formatDate(iso: string) {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }
</script>

<div class="rounded-lg border bg-white p-5">
  <h2 class="text-sm font-semibold mb-3">댓글 ({comments.length})</h2>

  {#if comments.length > 0}
    <div class="space-y-3 mb-4">
      {#each comments as comment (comment.id)}
        <div class="flex items-start justify-between border-b pb-3 last:border-0">
          <div>
            <div class="flex gap-2 text-xs text-gray-500">
              <span class="font-medium text-gray-700">{comment.author_name}</span>
              <span>{formatDate(comment.created_at)}</span>
            </div>
            <p class="mt-1 text-sm whitespace-pre-wrap">{comment.content}</p>
          </div>
          {#if comment.author_id === currentUserId || isAdmin}
            <form method="POST" action="?/deleteComment" use:enhance>
              <input type="hidden" name="commentId" value={comment.id} />
              <button type="submit" class="text-xs text-gray-400 hover:text-red-500">삭제</button>
            </form>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <form method="POST" action="?/comment" use:enhance={() => {
    return async ({ update }) => {
      commentText = '';
      await update();
    };
  }}>
    {#if error}
      <p class="mb-2 text-xs text-red-600">{error}</p>
    {/if}
    <div class="flex gap-2">
      <input
        name="content"
        bind:value={commentText}
        class="flex-1 rounded border px-3 py-2 text-sm"
        placeholder="댓글을 입력하세요"
        maxlength={2000}
      />
      <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">등록</button>
    </div>
  </form>
</div>
