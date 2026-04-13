<script lang="ts">
  import AdminNav from '$lib/components/AdminNav.svelte';

  let { data, children } = $props();
</script>

<div class="flex flex-col gap-4">
  <div>
    <h1 class="text-2xl font-bold">관리자</h1>
    <p class="mt-1 text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <AdminNav slug={data.currentTenant.slug} />

  {@render children?.()}
</div>
