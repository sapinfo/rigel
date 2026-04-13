<script lang="ts">
  import BoardList from '$lib/components/BoardList.svelte';

  let { data } = $props();
  const slug = data.currentTenant.slug;
</script>

<div class="space-y-4">
  <h1 class="text-xl font-bold">게시판</h1>
  <BoardList boards={data.boards} {slug} />
</div>
