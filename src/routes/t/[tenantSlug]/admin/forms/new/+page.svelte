<script lang="ts">
  import { enhance } from '$app/forms';
  import { untrack } from 'svelte';

  let { data, form } = $props();

  let submitting = $state(false);
  let schemaText = $state(untrack(() => form?.values?.schema ?? data.templateJson));
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center gap-2">
    <a
      href={`/t/${data.currentTenant.slug}/admin/forms`}
      class="text-sm text-gray-500 hover:text-gray-700"
    >
      ← 양식 목록
    </a>
  </div>

  <h2 class="text-lg font-semibold">새 양식</h2>

  <form
    method="POST"
    class="flex flex-col gap-4"
    use:enhance={() => {
      submitting = true;
      return async ({ update }) => {
        await update({ reset: false });
        submitting = false;
      };
    }}
  >
    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">양식 코드 <span class="text-red-500">*</span></span>
      <input
        type="text"
        name="code"
        required
        value={form?.values?.code ?? ''}
        placeholder="예: custom-request"
        pattern="[a-z0-9][a-z0-9-]*[a-z0-9]"
        class="rounded border px-3 py-2 font-mono text-sm"
      />
      <span class="text-xs text-gray-500">
        소문자·숫자·하이픈. URL에 사용됩니다. 테넌트 내 유일해야 함.
      </span>
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">양식 이름 <span class="text-red-500">*</span></span>
      <input
        type="text"
        name="name"
        required
        maxlength="100"
        value={form?.values?.name ?? ''}
        class="rounded border px-3 py-2 text-sm"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">설명</span>
      <input
        type="text"
        name="description"
        maxlength="500"
        value={form?.values?.description ?? ''}
        class="rounded border px-3 py-2 text-sm"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">JSON 스키마 <span class="text-red-500">*</span></span>
      <textarea
        name="schema"
        required
        rows="18"
        bind:value={schemaText}
        class="rounded border px-3 py-2 font-mono text-xs"
      ></textarea>
      <span class="text-xs text-gray-500">
        <code>{`{ version: 1, fields: [...] }`}</code> 형식. 각 필드는 id/type/label 필수.
        지원 타입: text, textarea, number, date, date-range, select, attachment
      </span>
    </label>

    <label class="inline-flex items-center gap-2">
      <input type="checkbox" name="is_published" />
      <span class="text-sm">발행 (기안자에게 노출)</span>
    </label>

    {#if form?.errors?.form}
      <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
        {form.errors.form}
      </p>
    {/if}
    {#each Object.entries(form?.errors?.fields ?? {}) as [field, msg]}
      <p class="text-xs text-red-500">{field}: {msg}</p>
    {/each}

    <div class="flex justify-end gap-2">
      <a
        href={`/t/${data.currentTenant.slug}/admin/forms`}
        class="rounded border px-4 py-2 text-sm hover:bg-gray-50"
      >
        취소
      </a>
      <button
        type="submit"
        name="next"
        value="list"
        disabled={submitting}
        class="rounded border border-blue-600 px-4 py-2 text-sm text-blue-700 hover:bg-blue-50 disabled:opacity-50"
      >
        {submitting ? '생성 중…' : '양식 생성'}
      </button>
      <button
        type="submit"
        name="next"
        value="builder"
        disabled={submitting}
        class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
        title="생성 후 빌더로 이동"
      >
        {submitting ? '생성 중…' : '빌더로 생성 →'}
      </button>
    </div>
  </form>
</div>
