<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();

  // ── 탭 ──────────────────────────────────────────
  let activeTab = $state<'org' | 'titles' | 'members'>('org');

  // ── 부서 트리 빌드 ────────────────────────────────
  type TreeNode = {
    id: string;
    name: string;
    parentId: string | null;
    memberCount: number;
    children: TreeNode[];
  };

  const tree = $derived.by(() => {
    const map = new Map<string, TreeNode>();
    for (const d of data.departments) {
      map.set(d.id, { id: d.id, name: d.name, parentId: d.parentId, memberCount: 0, children: [] });
    }
    for (const m of data.members) {
      if (m.departmentId && map.has(m.departmentId)) {
        map.get(m.departmentId)!.memberCount++;
      }
    }
    const roots: TreeNode[] = [];
    for (const node of map.values()) {
      if (node.parentId && map.has(node.parentId)) {
        map.get(node.parentId)!.children.push(node);
      } else {
        roots.push(node);
      }
    }
    return roots;
  });

  // ── 직급별 멤버 수 ──────────────────────────────
  const jtMemberCounts = $derived(
    data.members.reduce((acc, m) => {
      if (m.jobTitleId) acc[m.jobTitleId] = (acc[m.jobTitleId] ?? 0) + 1;
      return acc;
    }, {} as Record<string, number>)
  );

  // ── 부서 추가 state ─────────────────────────────
  let newDeptName = $state('');
  let newDeptParentId = $state('');

  // ── 직급 추가 state ─────────────────────────────
  let newJtName = $state('');
  let newJtLevel = $state(1);

  // ── 편집 state ──────────────────────────────────
  let editingDeptId = $state<string | null>(null);
  let editDeptName = $state('');
  let editingJtId = $state<string | null>(null);
  let editJtName = $state('');
  let editJtLevel = $state(1);
</script>

<div class="space-y-4">
  <h1 class="text-lg font-bold">조직 관리</h1>

  {#if form?.errors?.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.errors.form}</p>
  {/if}

  <!-- 탭 -->
  <div class="flex gap-1 border-b">
    {#each [['org', '조직도'], ['titles', '직급'], ['members', '멤버 배정']] as [key, label] (key)}
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium"
        class:border-b-2={activeTab === key}
        class:border-blue-600={activeTab === key}
        class:text-blue-600={activeTab === key}
        class:text-gray-500={activeTab !== key}
        onclick={() => activeTab = key as typeof activeTab}
      >
        {label}
      </button>
    {/each}
  </div>

  <!-- ═══ 조직도 탭 ═══════════════════════════════ -->
  {#if activeTab === 'org'}
    <!-- 부서 추가 폼 -->
    <form
      method="POST"
      action="?/createDept"
      class="flex items-end gap-2"
      use:enhance={() => {
        return async ({ update }) => { await update(); newDeptName = ''; newDeptParentId = ''; };
      }}
    >
      <label class="flex-1">
        <span class="text-xs text-gray-500">부서명</span>
        <input type="text" name="name" required bind:value={newDeptName} maxlength="100" placeholder="예: 영업팀" class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm" />
      </label>
      <label>
        <span class="text-xs text-gray-500">상위 부서</span>
        <select name="parentId" bind:value={newDeptParentId} class="mt-0.5 block rounded border px-3 py-1.5 text-sm">
          <option value="">최상위</option>
          {#each data.departments as d (d.id)}
            <option value={d.id}>{d.name}</option>
          {/each}
        </select>
      </label>
      <button type="submit" class="rounded bg-blue-600 px-4 py-1.5 text-sm text-white hover:bg-blue-700">추가</button>
    </form>

    <!-- 트리 -->
    {#if tree.length === 0}
      <div class="rounded-lg border bg-white p-8 text-center text-sm text-gray-500">부서가 없습니다. 위에서 추가하세요.</div>
    {:else}
      <div class="rounded-lg border bg-white p-4">
        {#each tree as node (node.id)}
          {@render deptNode(node, 0)}
        {/each}
      </div>
    {/if}

  <!-- ═══ 직급 탭 ═════════════════════════════════ -->
  {:else if activeTab === 'titles'}
    <!-- 직급 추가 폼 -->
    <form
      method="POST"
      action="?/createJobTitle"
      class="flex items-end gap-2"
      use:enhance={() => {
        return async ({ update }) => { await update(); newJtName = ''; newJtLevel = 1; };
      }}
    >
      <label class="flex-1">
        <span class="text-xs text-gray-500">직급명</span>
        <input type="text" name="name" required bind:value={newJtName} maxlength="100" placeholder="예: 사원" class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm" />
      </label>
      <label>
        <span class="text-xs text-gray-500">레벨 (1~10)</span>
        <input type="number" name="level" min="1" max="10" bind:value={newJtLevel} class="mt-0.5 block w-20 rounded border px-3 py-1.5 text-sm" />
      </label>
      <button type="submit" class="rounded bg-blue-600 px-4 py-1.5 text-sm text-white hover:bg-blue-700">추가</button>
    </form>

    <p class="text-xs text-gray-400">레벨이 높을수록 상위 직급 (1=사원, 5=과장, 7=부장, 10=대표)</p>

    <!-- 직급 목록 -->
    {#if data.jobTitles.length === 0}
      <div class="rounded-lg border bg-white p-8 text-center text-sm text-gray-500">직급이 없습니다.</div>
    {:else}
      <table class="w-full rounded-lg border bg-white text-sm">
        <thead>
          <tr class="border-b bg-gray-50 text-left text-xs text-gray-500">
            <th class="px-3 py-2">Lv</th>
            <th class="px-3 py-2">직급명</th>
            <th class="px-3 py-2">멤버 수</th>
            <th class="px-3 py-2">액션</th>
          </tr>
        </thead>
        <tbody>
          {#each data.jobTitles as jt (jt.id)}
            <tr class="border-b last:border-b-0">
              {#if editingJtId === jt.id}
                <td class="px-3 py-2">
                  <input type="number" min="1" max="10" bind:value={editJtLevel} class="w-14 rounded border px-2 py-0.5 text-sm" />
                </td>
                <td class="px-3 py-2">
                  <input type="text" bind:value={editJtName} class="w-full rounded border px-2 py-0.5 text-sm" />
                </td>
                <td class="px-3 py-2 text-gray-400">{jtMemberCounts[jt.id] ?? 0}</td>
                <td class="flex gap-1 px-3 py-2">
                  <form method="POST" action="?/updateJobTitle" use:enhance={() => {
                    return async ({ update }) => { await update(); editingJtId = null; };
                  }}>
                    <input type="hidden" name="id" value={jt.id} />
                    <input type="hidden" name="name" value={editJtName} />
                    <input type="hidden" name="level" value={editJtLevel} />
                    <button type="submit" class="rounded bg-blue-100 px-2 py-0.5 text-xs text-blue-700">저장</button>
                  </form>
                  <button type="button" onclick={() => editingJtId = null} class="text-xs text-gray-500">취소</button>
                </td>
              {:else}
                <td class="px-3 py-2 font-mono text-gray-400">{jt.level}</td>
                <td class="px-3 py-2 font-medium">{jt.name}</td>
                <td class="px-3 py-2 text-gray-400">{jtMemberCounts[jt.id] ?? 0}명</td>
                <td class="flex gap-1 px-3 py-2">
                  <button type="button" onclick={() => { editingJtId = jt.id; editJtName = jt.name; editJtLevel = jt.level; }} class="text-xs text-gray-500 hover:underline">편집</button>
                  <form method="POST" action="?/removeJobTitle" use:enhance onsubmit={(e) => { if (!confirm(`"${jt.name}" 직급을 삭제하시겠습니까?`)) e.preventDefault(); }}>
                    <input type="hidden" name="id" value={jt.id} />
                    <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
                  </form>
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}

  <!-- ═══ 멤버 배정 탭 ═══════════════════════════ -->
  {:else if activeTab === 'members'}
    <p class="text-xs text-gray-400">멤버별 소속 부서와 직급을 설정합니다. 결재선 자동 구성에 사용됩니다.</p>

    <table class="w-full rounded-lg border bg-white text-sm">
      <thead>
        <tr class="border-b bg-gray-50 text-left text-xs text-gray-500">
          <th class="px-3 py-2">이름</th>
          <th class="px-3 py-2">이메일</th>
          <th class="px-3 py-2">부서</th>
          <th class="px-3 py-2">직급</th>
        </tr>
      </thead>
      <tbody>
        {#each data.members as m (m.userId)}
          <tr class="border-b last:border-b-0">
            <td class="px-3 py-2 font-medium">{m.displayName}</td>
            <td class="px-3 py-2 text-gray-400">{m.email}</td>
            <td class="px-3 py-2">
              <form method="POST" action="?/assignDept" use:enhance={() => {
                return async ({ update }) => { await update({ reset: false }); };
              }}>
                <input type="hidden" name="userId" value={m.userId} />
                <select
                  name="departmentId"
                  class="rounded border px-2 py-0.5 text-sm"
                  value={m.departmentId ?? ''}
                  onchange={(e) => e.currentTarget.form?.requestSubmit()}
                >
                  <option value="">미지정</option>
                  {#each data.departments as d (d.id)}
                    <option value={d.id}>{d.name}</option>
                  {/each}
                </select>
              </form>
            </td>
            <td class="px-3 py-2">
              <form method="POST" action="?/assignJobTitle" use:enhance={() => {
                return async ({ update }) => { await update({ reset: false }); };
              }}>
                <input type="hidden" name="userId" value={m.userId} />
                <select
                  name="jobTitleId"
                  class="rounded border px-2 py-0.5 text-sm"
                  value={m.jobTitleId ?? ''}
                  onchange={(e) => e.currentTarget.form?.requestSubmit()}
                >
                  <option value="">미지정</option>
                  {#each data.jobTitles as jt (jt.id)}
                    <option value={jt.id}>{jt.name} (Lv.{jt.level})</option>
                  {/each}
                </select>
              </form>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<!-- ═══ 부서 트리 노드 (재귀 snippet) ═══════════ -->
{#snippet deptNode(node: TreeNode, depth: number)}
  <div style="padding-left: {depth * 1.5}rem">
    <div class="group flex items-center gap-2 rounded px-2 py-1.5 hover:bg-gray-50">
      <!-- 접기 indicator (children 있으면) -->
      {#if node.children.length > 0}
        <span class="text-xs text-gray-400">▼</span>
      {:else}
        <span class="w-3"></span>
      {/if}

      {#if editingDeptId === node.id}
        <!-- 편집 모드 -->
        <form method="POST" action="?/updateDept" class="flex flex-1 items-center gap-2" use:enhance={() => {
          return async ({ update }) => { await update(); editingDeptId = null; };
        }}>
          <input type="hidden" name="id" value={node.id} />
          <input type="text" name="name" bind:value={editDeptName} class="flex-1 rounded border px-2 py-0.5 text-sm" />
          <button type="submit" class="rounded bg-blue-100 px-2 py-0.5 text-xs text-blue-700">저장</button>
          <button type="button" onclick={() => editingDeptId = null} class="text-xs text-gray-500">취소</button>
        </form>
      {:else}
        <!-- 표시 모드 -->
        <span class="font-medium">{node.name}</span>
        <span class="text-xs text-gray-400">({node.memberCount}명)</span>

        <!-- 상위 부서 변경 -->
        <form method="POST" action="?/reparent" class="ml-2 hidden group-hover:block" use:enhance>
          <input type="hidden" name="id" value={node.id} />
          <select name="newParentId" class="rounded border px-1 py-0.5 text-xs" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
            <option value="">최상위로 이동</option>
            {#each data.departments.filter(d => d.id !== node.id) as d (d.id)}
              <option value={d.id} selected={d.id === node.parentId}>{d.name}</option>
            {/each}
          </select>
        </form>

        <div class="ml-auto hidden gap-1 group-hover:flex">
          <button type="button" onclick={() => { editingDeptId = node.id; editDeptName = node.name; }} class="text-xs text-gray-500 hover:underline">이름변경</button>
          <form method="POST" action="?/removeDept" use:enhance onsubmit={(e) => { if (!confirm(`"${node.name}" 부서를 삭제하시겠습니까?`)) e.preventDefault(); }}>
            <input type="hidden" name="id" value={node.id} />
            <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
          </form>
        </div>
      {/if}
    </div>

    {#if node.children.length > 0}
      {#each node.children as child (child.id)}
        {@render deptNode(child, depth + 1)}
      {/each}
    {/if}
  </div>
{/snippet}
