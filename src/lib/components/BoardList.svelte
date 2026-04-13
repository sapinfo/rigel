<script lang="ts">
  interface Board {
    id: string;
    name: string;
    board_type: string;
    description: string | null;
    post_count: number;
  }

  interface Props {
    boards: Board[];
    slug: string;
  }

  let { boards, slug }: Props = $props();
</script>

{#if boards.length === 0}
  <p class="text-sm text-gray-500">등록된 게시판이 없습니다. 관리자에게 문의하세요.</p>
{:else}
  <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
    {#each boards as board (board.id)}
      <a
        href="/t/{slug}/boards/{board.id}"
        class="rounded-lg border bg-white p-4 transition hover:shadow"
      >
        <div class="flex items-center gap-2">
          <h2 class="font-semibold">{board.name}</h2>
          {#if board.board_type === 'department'}
            <span class="text-xs rounded bg-blue-100 px-1.5 py-0.5 text-blue-700">부서</span>
          {/if}
        </div>
        {#if board.description}
          <p class="mt-1 text-sm text-gray-500 line-clamp-2">{board.description}</p>
        {/if}
        <p class="mt-2 text-xs text-gray-400">게시글 {board.post_count}건</p>
      </a>
    {/each}
  </div>
{/if}
