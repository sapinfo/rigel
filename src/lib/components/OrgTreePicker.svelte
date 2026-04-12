<script lang="ts">
  /**
   * OrgTreePicker — 조직도 트리에서 멤버를 선택하는 picker (v2.2 M11).
   * ApproverPicker의 상위 호환. 부서 계층으로 멤버 탐색.
   */
  type Dept = { id: string; name: string; parentId: string | null };
  type Member = { id: string; displayName: string; email: string; departmentId: string | null; jobTitle: string | null };
  type TreeNode = { dept: Dept; members: Member[]; children: TreeNode[] };

  type Props = {
    departments: Dept[];
    members: Member[];
    onSelect: (member: Member) => void;
    onClose: () => void;
  };

  let { departments, members, onSelect, onClose }: Props = $props();

  let search = $state('');
  let expandedDepts = $state<Set<string>>(new Set(departments.map((d) => d.id)));

  // 트리 빌드
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

  // 검색 필터
  const filteredMembers = $derived(
    search.trim()
      ? members.filter((m) =>
          m.displayName.toLowerCase().includes(search.toLowerCase()) ||
          m.email.toLowerCase().includes(search.toLowerCase())
        )
      : null
  );

  function toggleExpand(id: string) {
    const next = new Set(expandedDepts);
    if (next.has(id)) next.delete(id); else next.add(id);
    expandedDepts = next;
  }
</script>

<div class="rounded-lg border bg-white shadow-lg">
  <div class="flex items-center justify-between border-b px-4 py-3">
    <h3 class="text-sm font-semibold">결재자 선택</h3>
    <button type="button" onclick={onClose} class="text-gray-400 hover:text-gray-600">×</button>
  </div>

  <!-- 검색 -->
  <div class="border-b px-4 py-2">
    <input type="text" bind:value={search} placeholder="이름 또는 이메일 검색" class="w-full rounded border px-3 py-1.5 text-sm" />
  </div>

  <div class="max-h-80 overflow-y-auto p-2">
    {#if filteredMembers}
      <!-- 검색 결과 -->
      {#each filteredMembers as m (m.id)}
        <button type="button" onclick={() => onSelect(m)} class="flex w-full items-center gap-2 rounded px-3 py-1.5 text-left text-sm hover:bg-blue-50">
          <span class="font-medium">{m.displayName}</span>
          <span class="text-xs text-gray-400">{m.jobTitle ?? ''}</span>
          <span class="ml-auto text-xs text-gray-400">{m.email}</span>
        </button>
      {/each}
      {#if filteredMembers.length === 0}
        <p class="px-3 py-4 text-center text-xs text-gray-400">검색 결과가 없습니다</p>
      {/if}
    {:else}
      <!-- 트리 뷰 -->
      {#each tree as node (node.dept.id)}
        {@render treeNode(node, 0)}
      {/each}
    {/if}
  </div>
</div>

{#snippet treeNode(node: TreeNode, depth: number)}
  <div style="padding-left: {depth * 1}rem">
    <button type="button" onclick={() => toggleExpand(node.dept.id)} class="flex w-full items-center gap-1 rounded px-2 py-1 text-sm font-medium text-gray-700 hover:bg-gray-50">
      <span class="text-xs text-gray-400">{expandedDepts.has(node.dept.id) ? '▼' : '▶'}</span>
      {node.dept.name}
      <span class="text-xs text-gray-400">({node.members.length})</span>
    </button>

    {#if expandedDepts.has(node.dept.id)}
      {#each node.members as m (m.id)}
        <button type="button" onclick={() => onSelect(m)} class="flex w-full items-center gap-2 rounded px-3 py-1 text-left text-sm hover:bg-blue-50" style="padding-left: {(depth + 1) * 1 + 0.5}rem">
          <span>{m.displayName}</span>
          <span class="text-xs text-gray-400">{m.jobTitle ?? ''}</span>
        </button>
      {/each}
      {#each node.children as child (child.dept.id)}
        {@render treeNode(child, depth + 1)}
      {/each}
    {/if}
  </div>
{/snippet}
