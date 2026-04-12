<script lang="ts">
  import { enhance } from '$app/forms';
  import RuleBuilder from '$lib/components/RuleBuilder.svelte';

  let { data, form } = $props();

  let builderMode = $state<'closed' | 'create' | 'edit'>('closed');
  let editingRuleId = $state<string | null>(null);

  // ── RuleBuilder 초기값 ────────────────────────
  let builderName = $state('');
  let builderFormId = $state('');
  let builderPriority = $state(100);
  let builderHasCond = $state(false);
  let builderCond = $state({ field: '', operator: 'eq', value: '' });
  let builderSteps = $state<any[]>([]);

  // ── 시뮬레이터 ────────────────────────────────
  let simFormId = $state('');
  let simContent = $state<Record<string, string>>({});
  let simResult = $state<any>(null);

  const simFormFields = $derived(
    data.availableForms.find((f) => f.id === simFormId)?.fields ?? []
  );

  function openCreate() {
    builderMode = 'create';
    editingRuleId = null;
    builderName = '';
    builderFormId = '';
    builderPriority = 100;
    builderHasCond = false;
    builderCond = { field: '', operator: 'eq', value: '' };
    builderSteps = [{ roleMode: 'role', role: 'team_lead', userId: '', stepType: 'approval', hasCondition: false, condition: { field: '', operator: 'eq', value: '' } }];
  }

  function openEdit(rule: typeof data.rules[0]) {
    builderMode = 'edit';
    editingRuleId = rule.id;
    builderName = rule.name;
    builderFormId = rule.formId ?? '';
    builderPriority = rule.priority;

    // Parse condition
    const cond = rule.conditionJson as { field?: string; operator?: string; value?: unknown } | null;
    builderHasCond = !!cond;
    builderCond = cond
      ? { field: cond.field ?? '', operator: cond.operator ?? 'eq', value: String(cond.value ?? '') }
      : { field: '', operator: 'eq', value: '' };

    // Parse steps from line_template_json
    const rawSteps = rule.lineTemplateJson as { role?: string; stepType?: string; condition?: any }[];
    builderSteps = (rawSteps ?? []).map((s) => {
      const roleStr = typeof s.role === 'string' ? s.role : '';
      const isUuid = /^[0-9a-f-]{36}$/.test(roleStr);
      return {
        roleMode: isUuid ? 'user' as const : 'role' as const,
        role: isUuid ? 'team_lead' : roleStr,
        userId: isUuid ? roleStr : '',
        stepType: s.stepType ?? 'approval',
        hasCondition: !!s.condition,
        condition: s.condition
          ? { field: s.condition.field ?? '', operator: s.condition.operator ?? 'eq', value: String(s.condition.value ?? '') }
          : { field: '', operator: 'eq', value: '' }
      };
    });
  }

  // 폼 ref for programmatic submit
  let saveFormEl = $state<HTMLFormElement | null>(null);
  let savePayload = $state<Record<string, string>>({});

  function handleBuilderSave(payload: { name: string; formId: string; priority: number; conditionJson: string | null; lineTemplateJson: string }) {
    savePayload = {
      name: payload.name,
      formId: payload.formId,
      priority: String(payload.priority),
      conditionJson: payload.conditionJson ?? '',
      lineTemplateJson: payload.lineTemplateJson,
      ...(editingRuleId ? { id: editingRuleId } : {})
    };
    // tick 후 submit
    requestAnimationFrame(() => saveFormEl?.requestSubmit());
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">결재선 규칙</h1>
    {#if builderMode === 'closed'}
      <button type="button" onclick={openCreate} class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">
        + 새 규칙
      </button>
    {/if}
  </div>

  {#if form?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.actionError}</p>
  {/if}
  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">저장되었습니다.</p>
  {/if}

  <!-- 숨겨진 저장 폼 -->
  <form
    bind:this={saveFormEl}
    method="POST"
    action={builderMode === 'edit' ? '?/update' : '?/create'}
    class="hidden"
    use:enhance={() => {
      return async ({ update }) => {
        await update();
        builderMode = 'closed';
        editingRuleId = null;
      };
    }}
  >
    {#each Object.entries(savePayload) as [key, val] (key)}
      <input type="hidden" name={key} value={val} />
    {/each}
  </form>

  <!-- RuleBuilder -->
  {#if builderMode !== 'closed'}
    <RuleBuilder
      mode={builderMode === 'create' ? 'create' : 'edit'}
      name={builderName}
      formId={builderFormId}
      priority={builderPriority}
      hasCondition={builderHasCond}
      condition={builderCond}
      steps={builderSteps}
      availableForms={data.availableForms}
      members={data.members}
      onSave={handleBuilderSave}
      onCancel={() => { builderMode = 'closed'; editingRuleId = null; }}
    />
  {/if}

  <!-- 규칙 목록 -->
  {#if data.rules.length === 0 && builderMode === 'closed'}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      결재선 규칙이 없습니다. 규칙을 추가하면 기안 시 자동으로 결재선이 구성됩니다.
    </div>
  {:else}
    <ul class="space-y-2">
      {#each data.rules as rule (rule.id)}
        <li class="rounded border bg-white px-4 py-3">
          <div class="flex items-center gap-3">
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <span class="font-medium">{rule.name}</span>
                <span class="text-xs text-gray-400">우선순위: {rule.priority}</span>
                {#if rule.formId}
                  {@const formName = data.availableForms.find(f => f.id === rule.formId)?.name}
                  {#if formName}
                    <span class="rounded bg-blue-50 px-1.5 py-0.5 text-xs text-blue-600">{formName}</span>
                  {/if}
                {:else}
                  <span class="rounded bg-gray-50 px-1.5 py-0.5 text-xs text-gray-500">전체 양식</span>
                {/if}
                {#if !rule.isActive}
                  <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-500">비활성</span>
                {/if}
              </div>
              <!-- 결재선 요약 -->
              <div class="mt-1 flex flex-wrap gap-1">
                {#each rule.lineTemplateJson as step, i (i)}
                  {@const s = step as { role?: string; stepType?: string }}
                  <span class="rounded bg-gray-100 px-1.5 py-0.5 text-xs">
                    {i + 1}. {s.role === 'team_lead' ? '팀장' : s.role === 'department_head' ? '부서장' : s.role === 'ceo' ? '대표' : '지정'} ({s.stepType === 'reference' ? '참조' : '승인'})
                  </span>
                {/each}
              </div>
            </div>

            <div class="flex items-center gap-2">
              <button type="button" onclick={() => openEdit(rule)} class="rounded bg-gray-100 px-2 py-1 text-xs hover:bg-gray-200">편집</button>

              <form method="POST" action="?/toggle" use:enhance>
                <input type="hidden" name="id" value={rule.id} />
                <input type="hidden" name="active" value={String(!rule.isActive)} />
                <button type="submit" class="rounded px-2 py-1 text-xs" class:bg-green-100={rule.isActive} class:text-green-700={rule.isActive} class:bg-gray-100={!rule.isActive}>
                  {rule.isActive ? '활성' : '비활성'}
                </button>
              </form>

              <form method="POST" action="?/delete" use:enhance onsubmit={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}>
                <input type="hidden" name="id" value={rule.id} />
                <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
              </form>
            </div>
          </div>
        </li>
      {/each}
    </ul>
  {/if}

  <!-- ═══ 시뮬레이터 (M5) ══════════════════════ -->
  <details class="rounded-lg border bg-white">
    <summary class="cursor-pointer px-4 py-3 text-sm font-semibold">결재선 시뮬레이션</summary>
    <div class="border-t px-4 py-3">
      <form
        method="POST"
        action="?/simulate"
        use:enhance={({ formData }) => {
          formData.set('formId', simFormId);
          formData.set('sampleContent', JSON.stringify(simContent));
          return async ({ result, update }) => {
            if (result.type === 'success' && result.data?.simulateResult) {
              simResult = result.data.simulateResult;
            }
            await update({ reset: false });
          };
        }}
      >
        <div class="space-y-2">
          <label class="block">
            <span class="text-xs text-gray-500">양식 선택</span>
            <select bind:value={simFormId} class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm">
              <option value="">선택</option>
              {#each data.availableForms as f (f.id)}
                <option value={f.id}>{f.name} ({f.code})</option>
              {/each}
            </select>
          </label>

          {#if simFormFields.length > 0}
            <div class="space-y-1">
              <p class="text-xs text-gray-400">샘플 데이터 (조건 평가에 사용)</p>
              {#each simFormFields as field (field.id)}
                <label class="flex items-center gap-2">
                  <span class="w-24 text-xs text-gray-500">{field.label}</span>
                  <input
                    type="text"
                    value={simContent[field.id] ?? ''}
                    oninput={(e) => simContent = { ...simContent, [field.id]: e.currentTarget.value }}
                    class="flex-1 rounded border px-2 py-1 text-sm"
                  />
                </label>
              {/each}
            </div>
          {/if}

          <button type="submit" disabled={!simFormId} class="rounded bg-gray-100 px-3 py-1.5 text-sm hover:bg-gray-200 disabled:opacity-50">
            시뮬레이션 실행
          </button>
        </div>
      </form>

      {#if simResult}
        <div class="mt-3 rounded border bg-gray-50 p-3">
          {#if simResult.error}
            <p class="text-sm text-amber-600">{simResult.error}</p>
          {:else if simResult.approvers.length === 0}
            <p class="text-sm text-gray-500">매칭되는 규칙이 없습니다.</p>
          {:else}
            <p class="mb-2 text-xs text-gray-500">규칙: {simResult.ruleName ?? '(알 수 없음)'}</p>
            {#each simResult.approvers as a, i (a.userId)}
              <div class="flex items-center gap-2 py-0.5 text-sm">
                <span class="font-mono text-gray-400">{i + 1}.</span>
                <span class="font-medium">{a.displayName}</span>
                {#if a.departmentName || a.jobTitleName}
                  <span class="text-xs text-gray-400">
                    {a.departmentName ?? ''}{a.jobTitleName ? `/${a.jobTitleName}` : ''}
                  </span>
                {/if}
                <span class="rounded bg-gray-100 px-1.5 py-0.5 text-xs">{a.stepType === 'approval' ? '승인' : '참조'}</span>
              </div>
            {/each}
          {/if}
        </div>
      {/if}
    </div>
  </details>
</div>
