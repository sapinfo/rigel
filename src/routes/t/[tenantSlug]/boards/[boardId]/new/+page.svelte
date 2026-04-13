<script lang="ts">
  import { enhance } from '$app/forms';
  import RichEditor from '$lib/components/RichEditor.svelte';

  let { data, form } = $props();
  const slug = data.currentTenant.slug;

  let contentHtml = $state('');
  let title = $state('');
</script>

<div class="space-y-4">
  <h1 class="text-xl font-bold">{data.board.name} — 글쓰기</h1>

  {#if form?.error}
    <p class="rounded bg-red-50 p-3 text-sm text-red-600">{form.error}</p>
  {/if}

  <form
    method="POST"
    use:enhance={({ formData }) => {
      // Tiptap content를 JSON으로 전달
      formData.set('content', JSON.stringify({ html: contentHtml }));
    }}
    class="space-y-4"
  >
    <label class="block">
      <span class="text-sm font-medium">제목</span>
      <input
        name="title"
        bind:value={title}
        class="mt-1 block w-full rounded border px-3 py-2 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
        placeholder="제목을 입력하세요"
        required
      />
    </label>

    <div>
      <span class="text-sm font-medium">내용</span>
      <div class="mt-1">
        <RichEditor value="" onChange={(html) => (contentHtml = html)} />
      </div>
    </div>

    <div class="flex gap-2">
      <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">
        등록
      </button>
      <a href="/t/{slug}/boards/{data.board.id}" class="rounded border px-4 py-2 text-sm hover:bg-gray-50">
        취소
      </a>
    </div>
  </form>
</div>
