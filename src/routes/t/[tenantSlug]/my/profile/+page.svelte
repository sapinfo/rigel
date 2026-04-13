<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
  const p = $derived(data.profile);
</script>

<h1 class="text-xl font-bold mb-6">내 프로필</h1>

{#if form?.success}
  <div class="mb-4 rounded bg-green-50 border border-green-200 px-4 py-2 text-sm text-green-700">
    저장되었습니다.
  </div>
{/if}

<div class="rounded-lg border bg-white p-6 max-w-lg">
  <!-- Basic info (read-only) -->
  <div class="mb-6 space-y-2">
    <div class="flex items-center gap-2">
      <span class="text-sm text-gray-500 w-20">이름</span>
      <span class="text-sm font-medium">{data.fullName}</span>
    </div>
    <div class="flex items-center gap-2">
      <span class="text-sm text-gray-500 w-20">이메일</span>
      <span class="text-sm">{data.email}</span>
    </div>
  </div>

  <hr class="mb-4" />

  <form method="POST" action="?/save" use:enhance class="space-y-4">
    <div class="grid grid-cols-2 gap-4">
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">사번</span>
        <input name="employee_number" value={p?.employee_number ?? ''} class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">입사일</span>
        <input type="date" name="hire_date" value={p?.hire_date ?? ''} class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">직책</span>
        <input name="job_title" value={p?.job_title ?? ''} placeholder="팀장, 파트장" class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">직급</span>
        <input name="job_position" value={p?.job_position ?? ''} placeholder="과장, 차장" class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">사무실 전화</span>
        <input name="phone_office" value={p?.phone_office ?? ''} class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">휴대폰</span>
        <input name="phone_mobile" value={p?.phone_mobile ?? ''} class="w-full rounded border px-2 py-1.5 text-sm" />
      </label>
    </div>
    <label class="block">
      <span class="block text-xs text-gray-500 mb-1">자기소개</span>
      <textarea name="bio" rows="3" class="w-full rounded border px-2 py-1.5 text-sm">{p?.bio ?? ''}</textarea>
    </label>
    <button type="submit" class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700">저장</button>
  </form>
</div>
