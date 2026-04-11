<script lang="ts">
  import type { ProfileLite } from '$lib/types/approval';

  type Props = {
    members: ProfileLite[];
    excludeIds?: string[];
    onPick: (userId: string, stepType: 'approval' | 'reference') => void;
    onClose: () => void;
  };

  let { members, excludeIds = [], onPick, onClose }: Props = $props();

  let query = $state('');
  let selectedType = $state<'approval' | 'reference'>('approval');

  const filtered = $derived(
    members.filter((m) => {
      if (excludeIds.includes(m.id)) return false;
      if (!query.trim()) return true;
      const q = query.toLowerCase();
      return (
        m.displayName.toLowerCase().includes(q) ||
        m.email.toLowerCase().includes(q) ||
        (m.jobTitle ?? '').toLowerCase().includes(q)
      );
    })
  );
</script>

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/30"
  role="dialog"
  aria-modal="true"
>
  <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
    <div class="mb-4 flex items-center justify-between">
      <h3 class="text-lg font-semibold">결재자 추가</h3>
      <button type="button" class="text-gray-400 hover:text-gray-600" onclick={onClose}>✕</button>
    </div>

    <div class="mb-3 flex gap-2">
      <label class="flex items-center gap-1 text-sm">
        <input
          type="radio"
          bind:group={selectedType}
          value="approval"
        />
        결재
      </label>
      <label class="flex items-center gap-1 text-sm">
        <input
          type="radio"
          bind:group={selectedType}
          value="reference"
        />
        참조
      </label>
    </div>

    <input
      type="text"
      bind:value={query}
      placeholder="이름·이메일·직함 검색"
      class="mb-3 w-full rounded border px-3 py-2 text-sm"
    />

    <ul class="max-h-64 overflow-y-auto rounded border">
      {#each filtered as m (m.id)}
        <li>
          <button
            type="button"
            class="flex w-full items-center justify-between gap-2 px-3 py-2 text-left hover:bg-gray-50"
            onclick={() => onPick(m.id, selectedType)}
          >
            <div class="min-w-0 flex-1">
              <div class="truncate text-sm font-medium">{m.displayName}</div>
              <div class="truncate text-xs text-gray-500">
                {m.email}
                {#if m.jobTitle}· {m.jobTitle}{/if}
              </div>
            </div>
            <span class="text-xs text-blue-600">추가</span>
          </button>
        </li>
      {:else}
        <li class="px-3 py-4 text-center text-sm text-gray-500">결과 없음</li>
      {/each}
    </ul>
  </div>
</div>
