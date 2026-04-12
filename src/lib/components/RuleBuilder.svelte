<script lang="ts">
  /**
   * RuleBuilder — 결재선 규칙 시각적 빌더.
   * JSON textarea 대신 드롭다운·카드 기반 규칙 편집.
   */
  import ConditionEditor from './ConditionEditor.svelte';

  type ProfileLite = { id: string; displayName: string; jobTitle: string | null };
  type FormOption = { id: string; name: string; code: string; fields: { id: string; label: string }[] };

  type StepData = {
    roleMode: 'role' | 'user';
    role: string;      // 'team_lead' | 'department_head' | 'ceo'
    userId: string;    // UUID when roleMode='user'
    stepType: string;  // 'approval' | 'reference'
    hasCondition: boolean;
    condition: { field: string; operator: string; value: string };
  };

  type Props = {
    mode: 'create' | 'edit';
    name: string;
    formId: string;
    priority: number;
    hasCondition: boolean;
    condition: { field: string; operator: string; value: string };
    steps: StepData[];
    availableForms: FormOption[];
    members: ProfileLite[];
    onSave: (data: { name: string; formId: string; priority: number; conditionJson: string | null; lineTemplateJson: string }) => void;
    onCancel: () => void;
  };

  let {
    mode,
    name: initialName,
    formId: initialFormId,
    priority: initialPriority,
    hasCondition: initialHasCond,
    condition: initialCond,
    steps: initialSteps,
    availableForms,
    members,
    onSave,
    onCancel
  }: Props = $props();

  // ── State ──────────────────────────────────────
  let ruleName = $state(initialName);
  let selectedFormId = $state(initialFormId);
  let rulePriority = $state(initialPriority);
  let showCondition = $state(initialHasCond);
  let ruleCondition = $state({ ...initialCond });
  let steps = $state<StepData[]>(initialSteps.map((s) => ({ ...s, condition: { ...s.condition } })));

  // 선택된 양식의 필드 목록
  const selectedFormFields = $derived(
    availableForms.find((f) => f.id === selectedFormId)?.fields ?? []
  );

  function addStep() {
    steps = [...steps, {
      roleMode: 'role',
      role: 'team_lead',
      userId: '',
      stepType: 'approval',
      hasCondition: false,
      condition: { field: '', operator: 'eq', value: '' }
    }];
  }

  function removeStep(idx: number) {
    steps = steps.filter((_, i) => i !== idx);
  }

  function handleSave() {
    // 규칙 조건 → JSON
    const conditionJson = showCondition && ruleCondition.field
      ? JSON.stringify({ field: ruleCondition.field, operator: ruleCondition.operator, value: ruleCondition.value })
      : null;

    // steps → LineTemplateStep[] JSON
    const lineTemplate = steps.map((s) => {
      const role = s.roleMode === 'user' ? s.userId : s.role;
      const step: Record<string, unknown> = { role, stepType: s.stepType };
      if (s.hasCondition && s.condition.field) {
        step.condition = { field: s.condition.field, operator: s.condition.operator, value: s.condition.value };
      }
      return step;
    });

    onSave({
      name: ruleName,
      formId: selectedFormId,
      priority: rulePriority,
      conditionJson,
      lineTemplateJson: JSON.stringify(lineTemplate)
    });
  }
</script>

<div class="space-y-4 rounded-lg border bg-white p-4">
  <h3 class="text-sm font-semibold">{mode === 'create' ? '새 규칙' : '규칙 편집'}</h3>

  <!-- 기본 정보 -->
  <div class="flex flex-wrap gap-3">
    <label class="flex-1">
      <span class="text-xs text-gray-500">규칙 이름</span>
      <input type="text" bind:value={ruleName} required class="mt-0.5 block w-full rounded border px-3 py-1.5 text-sm" placeholder="예: 일반 결재선" />
    </label>
    <label>
      <span class="text-xs text-gray-500">적용 양식</span>
      <select bind:value={selectedFormId} class="mt-0.5 block rounded border px-3 py-1.5 text-sm">
        <option value="">전체 양식</option>
        {#each availableForms as f (f.id)}
          <option value={f.id}>{f.name} ({f.code})</option>
        {/each}
      </select>
    </label>
    <label>
      <span class="text-xs text-gray-500">우선순위</span>
      <input type="number" min="1" bind:value={rulePriority} class="mt-0.5 block w-20 rounded border px-3 py-1.5 text-sm" />
    </label>
  </div>

  <!-- 규칙 조건 -->
  <div>
    <button type="button" onclick={() => showCondition = !showCondition} class="text-sm text-blue-600">
      {showCondition ? '▼ 적용 조건 접기' : '▶ 적용 조건 추가 (선택)'}
    </button>
    {#if showCondition}
      <div class="mt-2 rounded border border-blue-100 bg-blue-50/50 p-3">
        <ConditionEditor
          fields={selectedFormFields}
          condition={ruleCondition}
          onChange={(c) => ruleCondition = c}
        />
      </div>
    {/if}
  </div>

  <!-- 결재선 단계 -->
  <div>
    <div class="mb-2 flex items-center justify-between">
      <span class="text-sm font-medium">결재선 구성</span>
      <button type="button" onclick={addStep} class="rounded bg-gray-100 px-2 py-1 text-xs hover:bg-gray-200">+ 단계 추가</button>
    </div>

    {#if steps.length === 0}
      <p class="text-xs text-gray-400">결재 단계를 추가하세요.</p>
    {/if}

    <div class="space-y-2">
      {#each steps as step, idx (idx)}
        <div class="flex items-start gap-2 rounded border bg-gray-50 p-3">
          <span class="mt-1 text-sm font-semibold text-gray-400">{idx + 1}</span>

          <div class="flex-1 space-y-2">
            <div class="flex flex-wrap gap-2">
              <!-- Role 모드 -->
              <select bind:value={step.roleMode} class="rounded border px-2 py-1 text-sm">
                <option value="role">직급 기반</option>
                <option value="user">직접 지정</option>
              </select>

              {#if step.roleMode === 'role'}
                <select bind:value={step.role} class="rounded border px-2 py-1 text-sm">
                  <option value="team_lead">팀장</option>
                  <option value="department_head">부서장</option>
                  <option value="ceo">대표</option>
                </select>
              {:else}
                <select bind:value={step.userId} class="rounded border px-2 py-1 text-sm">
                  <option value="">-- 멤버 선택 --</option>
                  {#each members as m (m.id)}
                    <option value={m.id}>{m.displayName} ({m.jobTitle ?? '직급없음'})</option>
                  {/each}
                </select>
              {/if}

              <!-- stepType -->
              <select bind:value={step.stepType} class="rounded border px-2 py-1 text-sm">
                <option value="approval">승인</option>
                <option value="reference">참조</option>
              </select>
            </div>

            <!-- Step 조건 -->
            <button type="button" onclick={() => step.hasCondition = !step.hasCondition} class="text-xs text-blue-500">
              {step.hasCondition ? '▼ 조건 접기' : '▶ 이 단계에 조건 추가'}
            </button>
            {#if step.hasCondition}
              <ConditionEditor
                fields={selectedFormFields}
                condition={step.condition}
                onChange={(c) => step.condition = c}
              />
            {/if}
          </div>

          <button type="button" onclick={() => removeStep(idx)} class="text-lg text-red-400 hover:text-red-600">×</button>
        </div>
      {/each}
    </div>
  </div>

  <!-- 하단 버튼 -->
  <div class="flex gap-2 border-t pt-3">
    <button type="button" onclick={handleSave} class="rounded bg-blue-600 px-4 py-1.5 text-sm text-white hover:bg-blue-700">
      {mode === 'create' ? '생성' : '저장'}
    </button>
    <button type="button" onclick={onCancel} class="rounded border px-4 py-1.5 text-sm hover:bg-gray-50">취소</button>
  </div>
</div>
