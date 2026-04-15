<script lang="ts">
  let { data, form } = $props();

  const errors = $derived(form?.errors ?? { fields: {} as Record<string, string>, form: null });
  const values = $derived(form?.values ?? {
    delegator_user_id: '',
    delegate_user_id: '',
    form_id: '',
    amount_limit: '',
    effective_from: '',
    effective_to: ''
  });

  const backHref = $derived(`/t/${data.currentTenant.slug}/admin/delegations`);
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center gap-2">
    <a href={backHref} class="text-sm text-gray-500 hover:underline">← 목록</a>
    <h2 class="text-lg font-semibold">새 전결 규칙</h2>
  </div>

  {#if errors.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {errors.form}
    </p>
  {/if}

  <form method="POST" class="flex max-w-xl flex-col gap-4 rounded-lg border bg-white p-6">
    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">
          위임자 (원 승인자) <span class="text-red-500">*</span>
        </span>
        <select
          name="delegator_user_id"
          value={values.delegator_user_id}
          class="rounded border px-3 py-2 text-sm"
          required
        >
          <option value="">-- 선택 --</option>
          {#each data.members as m (m.user_id)}
            <option value={m.user_id}>
              {m.display_name} ({m.email}){m.job_title ? ` / ${m.job_title}` : ''}
            </option>
          {/each}
        </select>
      </label>
      {#if errors.fields.delegator_user_id}
        <p class="text-xs text-red-600">{errors.fields.delegator_user_id}</p>
      {/if}
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">
          대리 수행자 <span class="text-red-500">*</span>
        </span>
        <select
          name="delegate_user_id"
          value={values.delegate_user_id}
          class="rounded border px-3 py-2 text-sm"
          required
        >
          <option value="">-- 선택 --</option>
          {#each data.members as m (m.user_id)}
            <option value={m.user_id}>
              {m.display_name} ({m.email}){m.job_title ? ` / ${m.job_title}` : ''}
            </option>
          {/each}
        </select>
      </label>
      {#if errors.fields.delegate_user_id}
        <p class="text-xs text-red-600">{errors.fields.delegate_user_id}</p>
      {/if}
      <p class="text-xs text-gray-500">
        위임 대상 감사 추적용으로 기록됩니다. 실제로는 해당 결재 단계가 skipped 처리됩니다.
      </p>
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">양식</span>
        <select
          name="form_id"
          value={values.form_id}
          class="rounded border px-3 py-2 text-sm"
        >
          <option value="">전 양식 (NULL)</option>
          {#each data.forms as f (f.id)}
            <option value={f.id}>{f.name} ({f.code})</option>
          {/each}
        </select>
      </label>
      {#if errors.fields.form_id}
        <p class="text-xs text-red-600">{errors.fields.form_id}</p>
      {/if}
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">금액 한도 (원)</span>
        <input
          type="number"
          name="amount_limit"
          value={values.amount_limit}
          min="0"
          step="1"
          placeholder="비워두면 금액 무관"
          class="rounded border px-3 py-2 text-sm"
        />
      </label>
      {#if errors.fields.amount_limit}
        <p class="text-xs text-red-600">{errors.fields.amount_limit}</p>
      {/if}
      <p class="text-xs text-gray-500">
        content.amount 필드가 이 값 이하일 때만 전결 적용. 빈 값이면 금액 무관.
      </p>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div class="flex flex-col gap-1">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">
            시작일 <span class="text-red-500">*</span>
          </span>
          <input
            type="date"
            name="effective_from"
            value={values.effective_from}
            class="rounded border px-3 py-2 text-sm"
            required
          />
        </label>
        {#if errors.fields.effective_from}
          <p class="text-xs text-red-600">{errors.fields.effective_from}</p>
        {/if}
      </div>
      <div class="flex flex-col gap-1">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">종료일</span>
          <input
            type="date"
            name="effective_to"
            value={values.effective_to}
            class="rounded border px-3 py-2 text-sm"
          />
        </label>
        {#if errors.fields.effective_to}
          <p class="text-xs text-red-600">{errors.fields.effective_to}</p>
        {/if}
      </div>
    </div>

    <div class="flex items-center justify-end gap-2 border-t pt-4">
      <a href={backHref} class="rounded border px-3 py-1.5 text-sm">취소</a>
      <button
        type="submit"
        class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
      >
        생성
      </button>
    </div>
  </form>
</div>
