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
  {#if form?.message}
    <div class="mb-4 rounded bg-red-50 border border-red-200 px-4 py-2 text-sm text-red-700">
      {form.message}
    </div>
  {/if}

  <form method="POST" action="?/save" use:enhance class="space-y-4">
    <!-- Identity: 이름은 수정 가능, 이메일은 auth 레벨이라 읽기 전용 -->
    <div class="grid grid-cols-2 gap-4">
      <label class="block">
        <span class="block text-xs text-gray-500 mb-1">이름</span>
        <input
          name="display_name"
          value={data.fullName}
          required
          maxlength="50"
          class="w-full rounded border px-2 py-1.5 text-sm"
        />
      </label>
      <div class="block">
        <span class="block text-xs text-gray-500 mb-1">이메일</span>
        <div class="w-full rounded border bg-gray-50 px-2 py-1.5 text-sm text-gray-700">
          {data.email}
        </div>
      </div>
    </div>

    <hr class="my-2" />

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
      <div class="block">
        <span class="block text-xs text-gray-500 mb-1">직급</span>
        <div class="w-full rounded border bg-gray-50 px-2 py-1.5 text-sm text-gray-700">
          {data.assignedJobTitle ? `${data.assignedJobTitle.name} (Lv.${data.assignedJobTitle.level})` : '미지정'}
        </div>
        <span class="mt-1 block text-xs text-gray-400">
          직급은 관리자가 `관리 &gt; 조직 관리 &gt; 멤버 배정`에서 지정합니다.
        </span>
      </div>
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
