<script lang="ts">
  import { enhance } from '$app/forms';

  interface Props {
    isAdmin: boolean;
    onclose: () => void;
  }

  let { isAdmin, onclose }: Props = $props();

  let title = $state('');
  let startAt = $state('');
  let endAt = $state('');
  let allDay = $state(false);
  let eventType = $state('personal');
  let color = $state('#3b82f6');
  let description = $state('');
</script>

<form method="POST" action="?/create" use:enhance={() => { return async ({ update }) => { onclose(); await update(); }; }} class="rounded-lg border bg-white p-4 space-y-3">
  <label class="block">
    <span class="text-sm font-medium">제목</span>
    <input name="title" bind:value={title} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
  </label>
  <div class="grid grid-cols-2 gap-3">
    <label class="block">
      <span class="text-sm font-medium">시작</span>
      <input type="datetime-local" name="start_at" bind:value={startAt} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
    </label>
    <label class="block">
      <span class="text-sm font-medium">종료</span>
      <input type="datetime-local" name="end_at" bind:value={endAt} class="mt-1 block w-full rounded border px-3 py-2 text-sm" required />
    </label>
  </div>
  <div class="flex flex-wrap gap-4">
    <label class="flex items-center gap-2 text-sm">
      <input type="checkbox" name="all_day" bind:checked={allDay} /> 종일
    </label>
    <label class="block">
      <span class="text-sm font-medium">유형</span>
      <select name="event_type" bind:value={eventType} class="ml-2 rounded border px-2 py-1 text-sm">
        <option value="personal">개인</option>
        {#if isAdmin}
          <option value="department">부서</option>
          <option value="company">전사</option>
        {/if}
      </select>
    </label>
    <label class="flex items-center gap-2 text-sm">
      <span>색상</span>
      <input type="color" name="color" bind:value={color} class="h-7 w-7 rounded border" />
    </label>
  </div>
  <label class="block">
    <span class="text-sm font-medium">설명</span>
    <textarea name="description" bind:value={description} rows={2} class="mt-1 block w-full rounded border px-3 py-2 text-sm"></textarea>
  </label>
  <div class="flex gap-2">
    <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">등록</button>
    <button type="button" onclick={onclose} class="rounded border px-4 py-2 text-sm">취소</button>
  </div>
</form>
