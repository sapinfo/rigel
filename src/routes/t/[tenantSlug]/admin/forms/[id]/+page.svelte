<script lang="ts">
  import { enhance } from '$app/forms';
  import { untrack } from 'svelte';

  let { data, form } = $props();

  let submitting = $state(false);
  let schemaText = $state(untrack(() => form?.values?.schema ?? data.form.schemaJson));
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

  <div>
    <h2 class="text-lg font-semibold">양식 편집</h2>
    <p class="text-xs text-gray-500">현재 버전: v{data.form.version} (저장 시 +1)</p>
  </div>

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
      <span class="text-sm font-medium">양식 코드</span>
      <input
        type="text"
        name="code"
        required
        value={form?.values?.code ?? data.form.code}
        pattern="[a-z0-9][a-z0-9-]*[a-z0-9]"
        class="rounded border px-3 py-2 font-mono text-sm"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">양식 이름</span>
      <input
        type="text"
        name="name"
        required
        maxlength="100"
        value={form?.values?.name ?? data.form.name}
        class="rounded border px-3 py-2 text-sm"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">설명</span>
      <input
        type="text"
        name="description"
        maxlength="500"
        value={form?.values?.description ?? data.form.description}
        class="rounded border px-3 py-2 text-sm"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">JSON 스키마</span>
      <textarea
        name="schema"
        required
        rows="24"
        bind:value={schemaText}
        class="rounded border px-3 py-2 font-mono text-xs"
      ></textarea>
    </label>

    <label class="inline-flex items-center gap-2">
      <input type="checkbox" name="is_published" checked={data.form.is_published} />
      <span class="text-sm">발행</span>
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
        disabled={submitting}
        class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
      >
        {submitting ? '저장 중…' : '저장'}
      </button>
    </div>
  </form>
</div>
