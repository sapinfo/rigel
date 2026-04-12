<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
  let file: File | null = $state(null);
  let clientError: string | null = $state(null);

  function onFile(e: Event) {
    const target = e.currentTarget as HTMLInputElement;
    const f = target.files?.[0];
    if (!f) { file = null; return; }
    if (f.size > 512 * 1024) { clientError = '파일 크기가 512KB를 초과합니다'; file = null; return; }
    if (f.type !== 'image/png') { clientError = 'PNG 파일만 업로드 가능'; file = null; return; }
    file = f;
    clientError = null;
  }
</script>

<div class="mx-auto max-w-lg space-y-6 p-6">
  <h1 class="text-xl font-semibold">서명 이미지 등록</h1>

  {#if data.currentSignatureUrl}
    <section class="space-y-2">
      <h2 class="text-sm text-gray-500">현재 서명</h2>
      <img src={data.currentSignatureUrl} alt="현재 서명" class="h-24 border border-gray-200" />
    </section>
  {/if}

  {#if form?.ok}
    <p class="rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-700">
      서명이 등록되었습니다.
    </p>
  {/if}

  <form method="POST" enctype="multipart/form-data" use:enhance>
    <label class="block space-y-1">
      <span class="text-sm font-medium text-gray-700">새 서명 PNG (투명 배경 권장, 최대 512KB)</span>
      <input type="file" name="signature" accept="image/png" onchange={onFile} required
        class="block w-full text-sm text-gray-500 file:mr-4 file:rounded file:border-0 file:bg-blue-50 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-blue-700 hover:file:bg-blue-100" />
    </label>

    {#if clientError}
      <p class="mt-2 text-sm text-red-600">{clientError}</p>
    {/if}
    {#if form?.actionError}
      <p class="mt-2 text-sm text-red-600">{form.actionError}</p>
    {/if}

    <button type="submit" disabled={!file}
      class="mt-4 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
      업로드
    </button>
  </form>
</div>
