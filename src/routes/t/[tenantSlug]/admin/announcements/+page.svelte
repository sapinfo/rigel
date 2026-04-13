<script lang="ts">
  import { enhance } from '$app/forms';
  import RichEditor from '$lib/components/RichEditor.svelte';

  let { data, form } = $props();

  let showCreate = $state(false);
  let newTitle = $state('');
  let newContent = $state('');
  let newIsPopup = $state(false);
  let newRequireConfirm = $state(false);
  let newExpiresAt = $state('');

  function formatDate(iso: string | null) {
    if (!iso) return '초안';
    return new Date(iso).toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' });
  }
</script>

<div class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-xl font-bold">공지 관리</h1>
    <button
      type="button"
      onclick={() => (showCreate = !showCreate)}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      + 공지 작성
    </button>
  </div>

  {#if form?.error}
    <p class="rounded bg-red-50 p-3 text-sm text-red-600">{form.error}</p>
  {/if}

  {#if showCreate}
    <form
      method="POST"
      action="?/create"
      use:enhance={({ formData }) => {
        formData.set('content', JSON.stringify({ html: newContent }));
      }}
      class="rounded-lg border bg-white p-4 space-y-3"
    >
      <label class="block">
        <span class="text-sm font-medium">제목</span>
        <input name="title" bind:value={newTitle} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
      </label>
      <div>
        <span class="text-sm font-medium">내용</span>
        <div class="mt-1">
          <RichEditor value="" onChange={(html) => (newContent = html)} />
        </div>
      </div>
      <div class="flex flex-wrap gap-4">
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" name="is_popup" bind:checked={newIsPopup} /> 팝업 표시
        </label>
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" name="require_read_confirm" bind:checked={newRequireConfirm} /> 필독 확인
        </label>
      </div>
      <label class="block">
        <span class="text-sm font-medium">만료일 (선택)</span>
        <input type="datetime-local" name="expires_at" bind:value={newExpiresAt} class="mt-1 block w-full rounded border px-3 py-2 text-sm" />
      </label>
      <div class="flex gap-2">
        <button type="submit" name="publish" value="true" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">발행</button>
        <button type="submit" name="publish" value="false" class="rounded border px-4 py-2 text-sm">초안 저장</button>
        <button type="button" onclick={() => (showCreate = false)} class="rounded border px-4 py-2 text-sm">취소</button>
      </div>
    </form>
  {/if}

  {#if data.announcements.length === 0}
    <p class="text-sm text-gray-500">공지사항이 없습니다.</p>
  {:else}
    <div class="overflow-x-auto rounded-lg border bg-white">
      <table class="w-full text-sm">
        <thead class="border-b bg-gray-50 text-left text-xs text-gray-500">
          <tr>
            <th class="px-4 py-2">제목</th>
            <th class="px-4 py-2">상태</th>
            <th class="px-4 py-2">읽음</th>
            <th class="px-4 py-2">옵션</th>
            <th class="px-4 py-2">작업</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          {#each data.announcements as ann (ann.id)}
            <tr>
              <td class="px-4 py-2.5 font-medium">{ann.title}</td>
              <td class="px-4 py-2.5 text-xs">
                {#if ann.published_at}
                  <span class="text-green-600">발행됨 ({formatDate(ann.published_at)})</span>
                {:else}
                  <span class="text-gray-400">초안</span>
                {/if}
              </td>
              <td class="px-4 py-2.5 text-xs text-gray-500">
                {ann.read_count} / {data.memberCount}
              </td>
              <td class="px-4 py-2.5 text-xs">
                {#if ann.is_popup}<span class="text-yellow-600 mr-1">팝업</span>{/if}
                {#if ann.require_read_confirm}<span class="text-red-600">필독</span>{/if}
              </td>
              <td class="px-4 py-2.5 flex gap-2">
                {#if !ann.published_at}
                  <form method="POST" action="?/publish" use:enhance class="inline">
                    <input type="hidden" name="id" value={ann.id} />
                    <button type="submit" class="text-xs text-blue-600 hover:underline">발행</button>
                  </form>
                {/if}
                <form method="POST" action="?/delete" use:enhance
                  onsubmit={(e) => { if (!confirm('삭제하시겠습니까?')) e.preventDefault(); }}
                  class="inline"
                >
                  <input type="hidden" name="id" value={ann.id} />
                  <button type="submit" class="text-xs text-red-500 hover:underline">삭제</button>
                </form>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
