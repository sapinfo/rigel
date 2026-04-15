<script lang="ts">
  /**
   * ApprovalLinePicker — 결재자 선택 통합 컴포넌트.
   *
   * 기존 ApproverPicker(flat list + radio) + OrgTreePicker(트리만) 를 하나로 합침.
   * - 상단 radio: 결재 / 합의 / 참조 (default 결재)
   * - 검색 미입력 시 부서 트리, 입력 시 flat 검색 결과
   * - 멤버 클릭 시 현재 selectedType 으로 `onPick` 호출 후 창 유지 (연속 추가)
   * - 이미 추가된(excludeIds) 멤버는 disabled + "추가됨" 뱃지
   * - ×, 닫기 버튼, ESC 키로 닫힘
   */
  import type { ProfileLite } from '$lib/types/approval';

  type Dept = { id: string; name: string; parentId: string | null };
  type TreeNode = { dept: Dept; members: ProfileLite[]; children: TreeNode[] };

  type Props = {
    members: ProfileLite[];
    departments: Dept[];
    excludeIds?: string[];
    onPick: (userId: string, stepType: 'approval' | 'agreement' | 'reference') => void;
    onClose: () => void;
  };

  let {
    members,
    departments,
    excludeIds = [],
    onPick,
    onClose
  }: Props = $props();

  let selectedType = $state<'approval' | 'agreement' | 'reference'>('approval');
  let search = $state('');
  let expandedDepts = $state<Set<string>>(new Set(departments.map((d) => d.id)));
  const excludeSet = $derived(new Set(excludeIds));

  // 부서 트리 (루트 부서 → 자식)
  const tree = $derived.by(() => {
    const map = new Map<string, TreeNode>();
    for (const d of departments) {
      map.set(d.id, { dept: d, members: [], children: [] });
    }
    for (const m of members) {
      if (m.departmentId && map.has(m.departmentId)) {
        map.get(m.departmentId)!.members.push(m);
      }
    }
    const roots: TreeNode[] = [];
    for (const node of map.values()) {
      if (node.dept.parentId && map.has(node.dept.parentId)) {
        map.get(node.dept.parentId)!.children.push(node);
      } else {
        roots.push(node);
      }
    }
    return roots;
  });

  // 검색 (이름·이메일·직함)
  const searchResults = $derived(
    search.trim()
      ? members.filter((m) => {
          const q = search.toLowerCase();
          return (
            m.displayName.toLowerCase().includes(q) ||
            m.email.toLowerCase().includes(q) ||
            (m.jobTitle ?? '').toLowerCase().includes(q)
          );
        })
      : null
  );

  function toggleExpand(id: string) {
    const next = new Set(expandedDepts);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    expandedDepts = next;
  }

  function pick(m: ProfileLite) {
    if (excludeSet.has(m.id)) return;
    onPick(m.id, selectedType);
    // 창은 유지. selectedType 도 유지 (같은 유형 연속 추가 편의).
  }

  function onKey(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }
</script>

<svelte:window onkeydown={onKey} />

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/30"
  role="dialog"
  aria-modal="true"
>
  <div class="flex w-full max-w-md flex-col rounded-lg bg-white shadow-xl">
    <div class="flex items-center justify-between border-b px-4 py-3">
      <h3 class="text-sm font-semibold">결재자 선택</h3>
      <button
        type="button"
        class="text-gray-400 hover:text-gray-600"
        aria-label="닫기"
        onclick={onClose}
      >
        ✕
      </button>
    </div>

    <!-- Step type 라디오 -->
    <div class="flex items-center gap-4 border-b px-4 py-2 text-sm">
      <label class="flex items-center gap-1">
        <input type="radio" bind:group={selectedType} value="approval" />
        <span>결재</span>
      </label>
      <label class="flex items-center gap-1">
        <input type="radio" bind:group={selectedType} value="agreement" />
        <span class="text-emerald-700">합의</span>
      </label>
      <label class="flex items-center gap-1">
        <input type="radio" bind:group={selectedType} value="reference" />
        <span class="text-gray-600">참조</span>
      </label>
      <span class="ml-auto text-xs text-gray-400">선택 후 계속 추가 가능</span>
    </div>

    <!-- 검색 -->
    <div class="border-b px-4 py-2">
      <input
        type="text"
        bind:value={search}
        placeholder="이름·이메일·직함 검색"
        class="w-full rounded border px-3 py-1.5 text-sm"
      />
    </div>

    <!-- 리스트 -->
    <div class="max-h-80 overflow-y-auto p-2">
      {#if searchResults}
        {#each searchResults as m (m.id)}
          {@const added = excludeSet.has(m.id)}
          <button
            type="button"
            disabled={added}
            onclick={() => pick(m)}
            class="flex w-full items-center gap-2 rounded px-3 py-1.5 text-left text-sm hover:bg-blue-50 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:bg-transparent"
          >
            <span class="font-medium">{m.displayName}</span>
            {#if m.jobTitle}
              <span class="text-xs text-gray-400">· {m.jobTitle}</span>
            {/if}
            <span class="ml-auto text-xs text-gray-400">{m.email}</span>
            {#if added}
              <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-500">추가됨</span>
            {/if}
          </button>
        {/each}
        {#if searchResults.length === 0}
          <p class="px-3 py-4 text-center text-xs text-gray-400">검색 결과가 없습니다</p>
        {/if}
      {:else}
        {#each tree as node (node.dept.id)}
          {@render treeNode(node, 0)}
        {/each}
      {/if}
    </div>
  </div>
</div>

{#snippet treeNode(node: TreeNode, depth: number)}
  <div style="padding-left: {depth * 0.75}rem">
    <button
      type="button"
      onclick={() => toggleExpand(node.dept.id)}
      class="flex w-full items-center gap-1 rounded px-2 py-1 text-sm font-medium text-gray-700 hover:bg-gray-50"
    >
      <span class="text-xs text-gray-400">
        {expandedDepts.has(node.dept.id) ? '▼' : '▶'}
      </span>
      {node.dept.name}
      <span class="text-xs text-gray-400">({node.members.length})</span>
    </button>

    {#if expandedDepts.has(node.dept.id)}
      {#each node.members as m (m.id)}
        {@const added = excludeSet.has(m.id)}
        <button
          type="button"
          disabled={added}
          onclick={() => pick(m)}
          class="flex w-full items-center gap-2 rounded px-3 py-1 text-left text-sm hover:bg-blue-50 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:bg-transparent"
          style="padding-left: {(depth + 1) * 0.75 + 0.5}rem"
        >
          <span>{m.displayName}</span>
          {#if m.jobTitle}
            <span class="text-xs text-gray-400">· {m.jobTitle}</span>
          {/if}
          {#if added}
            <span class="ml-auto rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-500">추가됨</span>
          {/if}
        </button>
      {/each}
      {#each node.children as child (child.dept.id)}
        {@render treeNode(child, depth + 1)}
      {/each}
    {/if}
  </div>
{/snippet}
