<script lang="ts">
  import type { ApprovalLineItem, ProfileLite } from '$lib/types/approval';
  import ApprovalLinePicker from './ApprovalLinePicker.svelte';

  // v1.2 M16b: 병렬 그룹 UX.
  // - 각 item 에 groupOrder 필드 (없으면 index 로 자동 할당, 순차).
  // - 체크박스로 여러 item 선택 후 "병렬 그룹으로 묶기" → 동일 groupOrder.
  // - "그룹 해제" → 각자 고유 groupOrder.
  // - 이동 버튼은 v1.3 로 이월 (그룹 기반 이동 복잡성). v1.2 는 add 순서가 곧 결재선 순서.
  // - 삭제/추가 후 자동 recompact (0, 1, ..., N-1 dense rank).

  type Dept = { id: string; name: string; parentId: string | null };

  type Props = {
    line: ApprovalLineItem[];
    members: ProfileLite[];
    departments?: Dept[];
    editable?: boolean;
    onChange?: (next: ApprovalLineItem[]) => void;
  };

  let { line, members, departments = [], editable = false, onChange }: Props = $props();
  let pickerOpen = $state(false);
  let selected = $state<Set<number>>(new Set());

  const profilesById = $derived(
    Object.fromEntries(members.map((m) => [m.id, m]))
  );

  // Normalize: undefined groupOrder → index (순차 기본)
  const normalized = $derived(
    line.map((item, idx) => ({
      ...item,
      groupOrder: item.groupOrder ?? idx
    }))
  );

  // Group 배지 표시용: dense rank 기반 (0, 1, 2, ...)
  const displayGroupOrders = $derived.by(() => {
    const unique = [...new Set(normalized.map((i) => i.groupOrder))].sort(
      (a, b) => a - b
    );
    const rank = new Map(unique.map((o, i) => [o, i]));
    return normalized.map((i) => rank.get(i.groupOrder) ?? 0);
  });

  function recompact(items: ApprovalLineItem[]): ApprovalLineItem[] {
    const withOrder = items.map((i, idx) => ({
      ...i,
      groupOrder: i.groupOrder ?? idx
    }));
    const unique = [...new Set(withOrder.map((i) => i.groupOrder))].sort(
      (a, b) => a - b
    );
    const rank = new Map(unique.map((o, i) => [o, i]));
    return withOrder.map((i) => ({ ...i, groupOrder: rank.get(i.groupOrder)! }));
  }

  function notify(next: ApprovalLineItem[]) {
    onChange?.(recompact(next));
    selected = new Set();
  }

  function removeAt(index: number) {
    notify(line.filter((_, i) => i !== index));
  }

  function addApprover(userId: string, stepType: 'approval' | 'agreement' | 'reference') {
    if (stepType === 'approval') {
      // 결재 = 새 그룹 (순차 진행)
      const maxGroup = normalized.reduce((m, i) => Math.max(m, i.groupOrder), -1);
      notify([...line, { userId, stepType, groupOrder: maxGroup + 1 }]);
    } else {
      // 합의·참조는 직전 결재 단계와 같은 그룹에 합류시킨다.
      // 이유:
      //   1) Zod refine: 각 그룹은 approval 을 1개 이상 포함해야 함
      //   2) fn_advance_document 는 다음 group 탐색 시 approval 만 고려 —
      //      합의/참조 단독 그룹은 도달 불가 (dead step) 이 됨
      const lastApproval = [...normalized]
        .reverse()
        .find((i) => i.stepType === 'approval');
      if (!lastApproval) {
        alert('합의/참조는 먼저 결재자를 추가한 뒤 등록할 수 있습니다.');
        return;
      }
      notify([...line, { userId, stepType, groupOrder: lastApproval.groupOrder }]);
    }
    // 연속 추가를 위해 창 유지. 닫기는 × 버튼 또는 ESC 로.
  }

  function toggleSelect(idx: number) {
    const next = new Set(selected);
    if (next.has(idx)) next.delete(idx);
    else next.add(idx);
    selected = next;
  }

  function groupSelected() {
    if (selected.size < 2) return;
    // 선택된 items 중 최소 groupOrder 를 기준 — 모두 그 값으로 통합
    const selectedIndices = [...selected];
    const minGroup = Math.min(
      ...selectedIndices.map((i) => normalized[i].groupOrder)
    );
    const next = line.map((item, idx) =>
      selected.has(idx) ? { ...item, groupOrder: minGroup } : item
    );
    notify(next);
  }

  function ungroupSelected() {
    if (selected.size === 0) return;
    // 선택된 items 각자 새 groupOrder (max + 1, max + 2, ...)
    const maxGroup = normalized.reduce(
      (m, i) => Math.max(m, i.groupOrder),
      -1
    );
    let counter = maxGroup + 1;
    const next = line.map((item, idx) => {
      if (selected.has(idx)) {
        return { ...item, groupOrder: counter++ };
      }
      return item;
    });
    notify(next);
  }
</script>

<div class="flex flex-col gap-2">
  <div class="flex items-center justify-between">
    <h3 class="text-sm font-semibold">결재선</h3>
    {#if editable && line.length >= 2}
      <div class="flex items-center gap-1 text-xs">
        <span class="text-gray-500">선택 {selected.size}명</span>
        <button
          type="button"
          class="rounded border px-2 py-0.5 hover:bg-blue-50 disabled:opacity-40"
          disabled={selected.size < 2}
          onclick={groupSelected}
        >
          병렬 그룹으로 묶기
        </button>
        <button
          type="button"
          class="rounded border px-2 py-0.5 hover:bg-gray-50 disabled:opacity-40"
          disabled={selected.size === 0}
          onclick={ungroupSelected}
        >
          그룹 해제
        </button>
      </div>
    {/if}
  </div>

  {#if line.length === 0}
    <p class="text-xs text-gray-500">아직 지정된 결재자가 없습니다.</p>
  {:else}
    <ol class="flex flex-col gap-1">
      {#each normalized as item, index (index + ':' + item.userId)}
        {@const profile = profilesById[item.userId]}
        {@const displayGroup = displayGroupOrders[index] + 1}
        {@const isParallel =
          displayGroupOrders.filter((g) => g === displayGroupOrders[index])
            .length > 1}
        <li class="flex items-center gap-2 rounded border bg-white px-3 py-2 text-sm">
          {#if editable}
            <input
              type="checkbox"
              checked={selected.has(index)}
              onchange={() => toggleSelect(index)}
              aria-label="그룹 선택"
            />
          {/if}
          <span
            class="rounded px-1.5 py-0.5 text-xs"
            class:bg-blue-50={isParallel}
            class:text-blue-700={isParallel}
            class:bg-gray-100={!isParallel}
            class:text-gray-700={!isParallel}
            title={isParallel ? '병렬 그룹' : '단독 그룹'}
          >
            G{displayGroup}
          </span>
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
            class:bg-emerald-100={item.stepType === 'agreement'}
            class:text-emerald-700={item.stepType === 'agreement'}
            class:bg-gray-100={item.stepType === 'reference'}
            class:text-gray-700={item.stepType === 'reference'}
          >
            {item.stepType === 'approval'
              ? '결재'
              : item.stepType === 'agreement'
                ? '합의'
                : '참조'}
          </span>
          {#if editable}
            <button
              type="button"
              class="text-xs text-red-500"
              onclick={() => removeAt(index)}
              aria-label="제거"
            >
              ✕
            </button>
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
  <ApprovalLinePicker
    {members}
    {departments}
    excludeIds={line.map((l) => l.userId)}
    onPick={addApprover}
    onClose={() => (pickerOpen = false)}
  />
{/if}
