<script lang="ts">
  import { enhance } from '$app/forms';
  import { ABSENCE_TYPES, ABSENCE_TYPE_LABELS } from '$lib/absenceTypes';

  let { data, form } = $props();

  const errors = $derived(form?.errors ?? { fields: {} as Record<string, string>, form: null });
  const values = $derived(
    form?.values ?? {
      delegate_user_id: '',
      absence_type: 'other',
      scope_form_id: '',
      start_at: '',
      end_at: '',
      reason: ''
    }
  );

  let showForm = $state(false);

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function isActive(from: string, to: string): boolean {
    const now = Date.now();
    return new Date(from).getTime() <= now && now <= new Date(to).getTime();
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <div>
      <h2 class="text-lg font-semibold">내 부재 관리</h2>
      <p class="mt-1 text-xs text-gray-500">
        부재 기간을 등록하면 해당 기간의 결재는 지정한 대리인이 승인할 수 있습니다.
      </p>
    </div>
    <button
      type="button"
      onclick={() => (showForm = !showForm)}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      {showForm ? '폼 닫기' : '+ 새 부재 등록'}
    </button>
  </div>

  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">
      부재가 등록되었습니다.
    </p>
  {/if}

  {#if errors.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {errors.form}
    </p>
  {/if}

  {#if showForm}
    <form
      method="POST"
      action="?/create"
      class="flex flex-col gap-4 rounded-lg border bg-white p-6"
      use:enhance={() => {
        return async ({ update }) => {
          await update();
        };
      }}
    >
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

      <div class="grid grid-cols-2 gap-3">
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
            <span class="text-sm font-medium">대리 범위</span>
            <select
              name="scope_form_id"
              value={values.scope_form_id}
              class="rounded border px-3 py-2 text-sm"
            >
              <option value="">전 결재</option>
              {#each data.forms as f (f.id)}
                <option value={f.id}>{f.name}</option>
              {/each}
            </select>
          </label>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-1">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              시작일시 <span class="text-red-500">*</span>
            </span>
            <input
              type="datetime-local"
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
              종료일시 <span class="text-red-500">*</span>
            </span>
            <input
              type="datetime-local"
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
        <button
          type="button"
          onclick={() => (showForm = false)}
          class="rounded border px-3 py-1.5 text-sm">취소</button
        >
        <button
          type="submit"
          class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
        >
          등록
        </button>
      </div>
    </form>
  {/if}

  {#if data.absences.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      등록된 부재가 없습니다.
    </div>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each data.absences as a (a.id)}
        {@const active = isActive(a.start_at, a.end_at)}
        <li class="rounded border bg-white px-4 py-3">
          <div class="flex items-start gap-3">
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs text-gray-500">대리인</span>
                <span class="font-medium">{a.delegate.display_name}</span>
                <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">
                  {ABSENCE_TYPE_LABELS[a.absence_type]}
                </span>
                {#if active}
                  <span class="rounded bg-green-100 px-2 py-0.5 text-xs text-green-700">
                    활성
                  </span>
                {:else}
                  <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">
                    비활성
                  </span>
                {/if}
              </div>
              <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-gray-600">
                <span>
                  <span class="text-gray-400">기간</span>
                  {formatDate(a.start_at)} ~ {formatDate(a.end_at)}
                </span>
                <span>
                  <span class="text-gray-400">범위</span>
                  {a.scope_form ? a.scope_form.name : '전 결재'}
                </span>
              </div>
              {#if a.reason}
                <p class="mt-1 text-xs text-gray-500">사유: {a.reason}</p>
              {/if}
            </div>

            <form
              method="POST"
              action="?/deleteAbsence"
              use:enhance={() => {
                return async ({ update }) => {
                  await update();
                };
              }}
            >
              <input type="hidden" name="id" value={a.id} />
              <button
                type="submit"
                class="rounded px-2 py-1 text-xs text-red-500 hover:bg-red-50"
                onclick={(e) => {
                  if (!confirm('이 부재를 삭제하시겠습니까?')) e.preventDefault();
                }}
              >
                삭제
              </button>
            </form>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>
