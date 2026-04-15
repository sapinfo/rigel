<script lang="ts">
  import { ABSENCE_TYPES, ABSENCE_TYPE_LABELS } from '$lib/absenceTypes';

  let { data, form } = $props();

  const errors = $derived(form?.errors ?? { fields: {} as Record<string, string>, form: null });
  const values = $derived(form?.values ?? data.initialValues);

  const backHref = $derived(`/t/${data.currentTenant.slug}/admin/absences`);
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center gap-2">
    <a href={backHref} class="text-sm text-gray-500 hover:underline">← 목록</a>
    <h2 class="text-lg font-semibold">부재 수정</h2>
  </div>

  <div class="rounded border bg-gray-50 px-4 py-3 text-xs text-gray-600">
    <div>부재 ID: <span class="font-mono">{data.absence.id}</span></div>
    <div>등록: {new Date(data.absence.created_at).toLocaleString('ko-KR')}</div>
  </div>

  {#if errors.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {errors.form}
    </p>
  {/if}

  <form
    method="POST"
    action="?/update"
    class="flex max-w-xl flex-col gap-4 rounded-lg border bg-white p-6"
  >
    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">
          부재자 (본인) <span class="text-red-500">*</span>
        </span>
        <select
          name="user_id"
          value={values.user_id}
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
      {#if errors.fields.user_id}
        <p class="text-xs text-red-600">{errors.fields.user_id}</p>
      {/if}
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">
          대리인 <span class="text-red-500">*</span>
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
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">부재 유형</span>
        <select
          name="absence_type"
          value={values.absence_type}
          class="rounded border px-3 py-2 text-sm"
        >
          {#each ABSENCE_TYPES as t}
            <option value={t}>{ABSENCE_TYPE_LABELS[t]}</option>
          {/each}
        </select>
      </label>
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">대리 범위 (양식)</span>
        <select
          name="scope_form_id"
          value={values.scope_form_id}
          class="rounded border px-3 py-2 text-sm"
        >
          <option value="">전 결재 (NULL)</option>
          {#each data.forms as f (f.id)}
            <option value={f.id}>{f.name} ({f.code})</option>
          {/each}
        </select>
      </label>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div class="flex flex-col gap-1">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">
            시작일 <span class="text-red-500">*</span>
          </span>
          <input
            type="date"
            name="start_at"
            value={values.start_at}
            class="rounded border px-3 py-2 text-sm"
            required
          />
        </label>
        {#if errors.fields.start_at}
          <p class="text-xs text-red-600">{errors.fields.start_at}</p>
        {/if}
      </div>
      <div class="flex flex-col gap-1">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">
            종료일 <span class="text-red-500">*</span>
          </span>
          <input
            type="date"
            name="end_at"
            value={values.end_at}
            class="rounded border px-3 py-2 text-sm"
            required
          />
        </label>
        {#if errors.fields.end_at}
          <p class="text-xs text-red-600">{errors.fields.end_at}</p>
        {/if}
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium">사유 (선택)</span>
        <textarea
          name="reason"
          value={values.reason}
          rows="2"
          maxlength="500"
          class="rounded border px-3 py-2 text-sm"
        ></textarea>
      </label>
    </div>

    <div class="flex items-center justify-end gap-2 border-t pt-4">
      <a href={backHref} class="rounded border px-3 py-1.5 text-sm">취소</a>
      <button
        type="submit"
        class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
      >
        저장
      </button>
    </div>
  </form>
</div>
