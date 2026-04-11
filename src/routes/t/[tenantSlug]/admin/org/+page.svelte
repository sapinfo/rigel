<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();

  let newName = $state('');
</script>

<div class="flex flex-col gap-4">
  <!-- 생성 -->
  <section class="rounded-lg border bg-white p-4">
    <h2 class="mb-3 text-base font-semibold">부서 추가</h2>
    <form
      method="POST"
      action="?/create"
      class="flex gap-2"
      use:enhance={() => {
        return async ({ update }) => {
          await update();
          newName = '';
        };
      }}
    >
      <input
        type="text"
        name="name"
        required
        bind:value={newName}
        maxlength="100"
        placeholder="부서명 (예: 영업팀)"
        class="flex-1 rounded border px-3 py-2 text-sm"
      />
      <button
        type="submit"
        class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
      >
        추가
      </button>
    </form>
    {#if form?.errors?.form}
      <p class="mt-2 text-sm text-red-600">{form.errors.form}</p>
    {/if}
  </section>

  <!-- 목록 -->
  <section>
    <h2 class="mb-2 text-base font-semibold">부서 ({data.departments.length})</h2>
    {#if data.departments.length === 0}
      <div class="rounded-lg border bg-white p-8 text-center text-sm text-gray-500">
        부서가 없습니다. 위에서 추가하세요.
      </div>
    {:else}
      <ul class="flex flex-col gap-1">
        {#each data.departments as d (d.id)}
          <li class="flex items-center gap-3 rounded border bg-white px-3 py-2">
            <form
              method="POST"
              action="?/rename"
              class="flex flex-1 items-center gap-2"
              use:enhance
            >
              <input type="hidden" name="id" value={d.id} />
              <input
                type="text"
                name="name"
                value={d.name}
                maxlength="100"
                class="flex-1 rounded border px-2 py-1 text-sm"
              />
              <button
                type="submit"
                class="rounded border px-2 py-1 text-xs hover:bg-gray-50"
              >
                이름 변경
              </button>
            </form>
            <span class="font-mono text-xs text-gray-400">{d.path}</span>
            <form
              method="POST"
              action="?/remove"
              use:enhance
              onsubmit={(e) => {
                if (!confirm(`"${d.name}" 부서를 삭제하시겠습니까?`)) e.preventDefault();
              }}
            >
              <input type="hidden" name="id" value={d.id} />
              <button type="submit" class="rounded px-2 py-1 text-xs text-red-500">
                삭제
              </button>
            </form>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <p class="text-xs text-gray-500">
    v1.0 제한: 평면 부서 구조만 지원. 트리·사용자 매핑은 v1.1+
  </p>
</div>
