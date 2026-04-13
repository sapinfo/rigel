<script lang="ts">
  interface Post {
    id: string;
    title: string;
    is_pinned: boolean;
    comment_count: number;
    author_name: string;
    created_at: string;
    view_count: number;
  }

  interface Props {
    posts: Post[];
    slug: string;
    boardId: string;
    page: number;
    totalPages: number;
  }

  let { posts, slug, boardId, page, totalPages }: Props = $props();

  function formatDate(iso: string) {
    return new Date(iso).toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' });
  }
</script>

{#if posts.length === 0}
  <p class="text-sm text-gray-500">게시글이 없습니다.</p>
{:else}
  <div class="overflow-x-auto rounded-lg border bg-white">
    <table class="w-full text-sm">
      <thead class="border-b bg-gray-50 text-left text-xs text-gray-500">
        <tr>
          <th class="px-4 py-2 w-full">제목</th>
          <th class="px-4 py-2 whitespace-nowrap">작성자</th>
          <th class="px-4 py-2 whitespace-nowrap">날짜</th>
          <th class="px-4 py-2 whitespace-nowrap text-right">조회</th>
        </tr>
      </thead>
      <tbody class="divide-y">
        {#each posts as post (post.id)}
          <tr class="hover:bg-gray-50">
            <td class="px-4 py-2.5">
              <a href="/t/{slug}/boards/{boardId}/{post.id}" class="hover:text-blue-600">
                {#if post.is_pinned}
                  <span class="mr-1 text-xs font-medium text-red-600">[공지]</span>
                {/if}
                {post.title}
                {#if post.comment_count > 0}
                  <span class="ml-1 text-xs text-blue-500">[{post.comment_count}]</span>
                {/if}
              </a>
            </td>
            <td class="px-4 py-2.5 text-gray-600 whitespace-nowrap">{post.author_name}</td>
            <td class="px-4 py-2.5 text-gray-400 whitespace-nowrap">{formatDate(post.created_at)}</td>
            <td class="px-4 py-2.5 text-gray-400 text-right">{post.view_count}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  {#if totalPages > 1}
    <div class="flex justify-center gap-2 text-sm mt-3">
      {#each Array.from({ length: totalPages }, (_, i) => i + 1) as p}
        <a
          href="?page={p}"
          class="rounded px-3 py-1 {p === page ? 'bg-blue-600 text-white' : 'border hover:bg-gray-50'}"
        >
          {p}
        </a>
      {/each}
    </div>
  {/if}
{/if}
