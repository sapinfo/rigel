<script lang="ts">
  import PostList from '$lib/components/PostList.svelte';

  let { data } = $props();
  const slug = data.currentTenant.slug;
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-xl font-bold">{data.board.name}</h1>
      {#if data.board.description}
        <p class="text-sm text-gray-500">{data.board.description}</p>
      {/if}
    </div>
    <a
      href="/t/{slug}/boards/{data.board.id}/new"
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      글쓰기
    </a>
  </div>

  <PostList
    posts={data.posts}
    {slug}
    boardId={data.board.id}
    page={data.page}
    totalPages={data.totalPages}
  />

  <a href="/t/{slug}/boards" class="text-sm text-gray-500 hover:underline">&larr; 게시판 목록</a>
</div>
