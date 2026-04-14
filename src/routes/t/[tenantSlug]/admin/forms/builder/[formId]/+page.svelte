<script lang="ts">
  import { enhance } from '$app/forms';
  import FormBuilder from '$lib/components/FormBuilder.svelte';
  import type { FormSchema } from '$lib/types/approval';

  let { data, form: formResult } = $props();

  // CLAUDE.md SvelteKit 규칙 §1: 복잡 state는 hidden input bind 대신
  // use:enhance에서 submit 시점에 formData에 주입 (stale 방지).
  let pendingSchema: FormSchema | null = null;

  function handleSave(schema: FormSchema) {
    pendingSchema = schema;
    const formEl = document.getElementById('save-form') as HTMLFormElement;
    formEl?.requestSubmit();
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-xl font-semibold">{data.form.name}</h1>
      <p class="text-sm text-gray-500">v{data.form.version} · {data.form.code} · {data.form.isPublished ? '발행됨' : '미발행'}</p>
    </div>
    <div class="flex gap-2">
      {#if !data.form.isPublished}
        <form method="POST" action="?/publish" use:enhance>
          <button type="submit" class="rounded bg-green-600 px-4 py-2 text-sm text-white hover:bg-green-700">
            발행
          </button>
        </form>
      {/if}
      <a href="/t/{data.currentTenant.slug}/admin/forms" class="rounded border px-4 py-2 text-sm hover:bg-gray-50">
        목록으로
      </a>
    </div>
  </div>

  {#if formResult?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">
      {formResult.published ? '양식이 발행되었습니다.' : '양식이 저장되었습니다.'}
    </p>
  {/if}
  {#if formResult?.actionError}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {formResult.actionError}
    </p>
  {/if}

  <form
    id="save-form"
    method="POST"
    action="?/save"
    use:enhance={({ formData, cancel }) => {
      if (!pendingSchema) {
        cancel();
        return;
      }
      formData.set('schema', JSON.stringify(pendingSchema));
    }}
    class="hidden"
  >
  </form>

  <FormBuilder
    initialSchema={data.form.schema}
    tenantId={data.currentTenant.id}
    onSave={handleSave}
  />
</div>
