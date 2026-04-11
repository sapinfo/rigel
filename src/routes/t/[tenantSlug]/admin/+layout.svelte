<script lang="ts">
  import { page } from '$app/state';

  let { data, children } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/admin`);

  const tabs = [
    { href: '/forms', label: '양식' },
    { href: '/members', label: '멤버' },
    { href: '/org', label: '조직도' }
  ];

  function isActive(href: string): boolean {
    return page.url.pathname.startsWith(`${baseHref}${href}`);
  }
</script>

<div class="flex flex-col gap-6">
  <div>
    <h1 class="text-2xl font-bold">관리자</h1>
    <p class="mt-1 text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <nav class="flex gap-0 border-b">
    {#each tabs as tab (tab.href)}
      {@const active = isActive(tab.href)}
      <a
        href={`${baseHref}${tab.href}`}
        class="border-b-2 px-4 py-2 text-sm"
        class:border-blue-600={active}
        class:text-blue-600={active}
        class:font-semibold={active}
        class:border-transparent={!active}
        class:text-gray-600={!active}
      >
        {tab.label}
      </a>
    {/each}
  </nav>

  {@render children?.()}
</div>
