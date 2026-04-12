<script lang="ts">
  import { page } from '$app/state';

  let { data, children } = $props();

  let newDraftOpen = $state(false);
  const printMode = $derived(page.url.searchParams.get('print') === '1');

  function closeDropdown() {
    newDraftOpen = false;
  }
</script>

<svelte:window onclick={closeDropdown} />

{#if !printMode}
<header class="border-b bg-white">
  <div class="mx-auto max-w-6xl px-6 py-4 flex items-center justify-between">
    <div class="flex items-center gap-4">
      <a href="/" class="text-xl font-bold">Rigel</a>
      <span class="text-gray-300">/</span>
      <span class="text-gray-700">{data.currentTenant.name}</span>
      <span class="text-xs px-2 py-0.5 rounded bg-gray-100 text-gray-600">
        {data.currentTenant.role}
      </span>
    </div>
    <nav class="flex items-center gap-4 text-sm">
      <!-- 새 기안 드롭다운 -->
      <div class="relative">
        <button
          type="button"
          class="rounded bg-blue-600 px-3 py-1.5 text-white hover:bg-blue-700"
          onclick={(e) => {
            e.stopPropagation();
            newDraftOpen = !newDraftOpen;
          }}
        >
          + 새 기안
        </button>
        {#if newDraftOpen}
          <div
            class="absolute right-0 top-full z-10 mt-1 min-w-48 rounded-lg border bg-white py-1 shadow-lg"
            role="menu"
            tabindex="-1"
            onclick={(e) => e.stopPropagation()}
            onkeydown={(e) => e.key === 'Escape' && (newDraftOpen = false)}
          >
            {#each data.forms as form (form.code)}
              <a
                href={`/t/${data.currentTenant.slug}/approval/drafts/new/${form.code}`}
                class="block px-3 py-2 text-sm hover:bg-gray-50"
                onclick={closeDropdown}
              >
                {form.name}
              </a>
            {:else}
              <p class="px-3 py-2 text-xs text-gray-500">양식 없음</p>
            {/each}
          </div>
        {/if}
      </div>

      <a href={`/t/${data.currentTenant.slug}/approval/inbox`} class="hover:underline">결재함</a>
      {#if data.currentTenant.role === 'owner' || data.currentTenant.role === 'admin'}
        <a href={`/t/${data.currentTenant.slug}/admin/members`} class="hover:underline">관리</a>
      {/if}
      <form method="POST" action="/logout" class="inline">
        <button type="submit" class="text-gray-500 hover:text-gray-900">로그아웃</button>
      </form>
    </nav>
  </div>
</header>
{/if}

<div class:mx-auto={!printMode} class:max-w-6xl={!printMode} class:px-6={!printMode} class:py-8={!printMode}>
  {@render children?.()}
</div>
