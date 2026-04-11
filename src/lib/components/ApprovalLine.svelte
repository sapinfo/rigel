<script lang="ts">
  import type { ApprovalLineItem, ProfileLite } from '$lib/types/approval';
  import ApproverPicker from './ApproverPicker.svelte';

  type Props = {
    line: ApprovalLineItem[];
    members: ProfileLite[];
    editable?: boolean;
    onChange?: (next: ApprovalLineItem[]) => void;
  };

  let { line, members, editable = false, onChange }: Props = $props();
  let pickerOpen = $state(false);

  const profilesById = $derived(
    Object.fromEntries(members.map((m) => [m.id, m]))
  );

  function notify(next: ApprovalLineItem[]) {
    onChange?.(next);
  }

  function removeAt(index: number) {
    notify(line.filter((_, i) => i !== index));
  }

  function move(index: number, dir: -1 | 1) {
    const target = index + dir;
    if (target < 0 || target >= line.length) return;
    const next = [...line];
    [next[index], next[target]] = [next[target], next[index]];
    notify(next);
  }

  function addApprover(userId: string, stepType: 'approval' | 'reference') {
    notify([...line, { userId, stepType }]);
    pickerOpen = false;
  }
</script>

<div class="flex flex-col gap-2">
  <h3 class="text-sm font-semibold">결재선</h3>
  {#if line.length === 0}
    <p class="text-xs text-gray-500">아직 지정된 결재자가 없습니다.</p>
  {:else}
    <ol class="flex flex-col gap-1">
      {#each line as item, index (index + ':' + item.userId)}
        {@const profile = profilesById[item.userId]}
        <li class="flex items-center gap-2 rounded border bg-white px-3 py-2 text-sm">
          <span class="w-6 text-gray-500">{index + 1}</span>
          <span class="flex-1 truncate">
            {profile?.displayName ?? '(알 수 없음)'}
            {#if profile?.jobTitle}
              <span class="text-xs text-gray-500">· {profile.jobTitle}</span>
            {/if}
          </span>
          <span
            class="rounded px-2 py-0.5 text-xs"
            class:bg-blue-100={item.stepType === 'approval'}
            class:text-blue-700={item.stepType === 'approval'}
            class:bg-gray-100={item.stepType === 'reference'}
            class:text-gray-700={item.stepType === 'reference'}
          >
            {item.stepType === 'approval' ? '결재' : '참조'}
          </span>
          {#if editable}
            <button
              type="button"
              class="text-xs"
              title="위로"
              onclick={() => move(index, -1)}>↑</button
            >
            <button
              type="button"
              class="text-xs"
              title="아래로"
              onclick={() => move(index, 1)}>↓</button
            >
            <button
              type="button"
              class="text-xs text-red-500"
              onclick={() => removeAt(index)}>✕</button
            >
          {/if}
        </li>
      {/each}
    </ol>
  {/if}

  {#if editable}
    <button
      type="button"
      class="mt-1 rounded border border-dashed px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
      onclick={() => (pickerOpen = true)}
    >
      + 결재자 추가
    </button>
  {/if}
</div>

{#if pickerOpen}
  <ApproverPicker
    {members}
    excludeIds={line.map((l) => l.userId)}
    onPick={addApprover}
    onClose={() => (pickerOpen = false)}
  />
{/if}
