<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/admin/forms`);
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <h2 class="text-lg font-semibold">양식</h2>
    <a
      href={`${baseHref}/new`}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      + 새 양식
    </a>
  </div>

  {#if form?.error}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {form.error}
    </p>
  {/if}

  {#if data.forms.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      양식이 없습니다. "+ 새 양식" 으로 추가하세요.
    </div>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each data.forms as f (f.id)}
        <li class="flex items-center gap-3 rounded border bg-white px-4 py-3">
          <a
            href={`${baseHref}/${f.id}`}
            class="min-w-0 flex-1 hover:underline"
          >
            <div class="flex items-center gap-2">
              <span class="font-medium">{f.name}</span>
              <span class="rounded bg-gray-100 px-2 py-0.5 font-mono text-xs text-gray-600">
                {f.code}
              </span>
              <span class="text-xs text-gray-400">v{f.version}</span>
            </div>
            {#if f.description}
              <p class="mt-1 truncate text-xs text-gray-500">{f.description}</p>
            {/if}
          </a>

          <form
            method="POST"
            action="?/togglePublish"
            use:enhance={() => {
              return async ({ update }) => {
                await update();
              };
            }}
          >
            <input type="hidden" name="id" value={f.id} />
            <input type="hidden" name="publish" value={!f.is_published} />
            <button
              type="submit"
              class="rounded px-2 py-1 text-xs"
              class:bg-green-100={f.is_published}
              class:text-green-700={f.is_published}
              class:bg-gray-100={!f.is_published}
              class:text-gray-600={!f.is_published}
              title={f.is_published ? '발행 취소' : '발행'}
            >
              {f.is_published ? '발행됨' : '미발행'}
            </button>
          </form>

          <form
            method="POST"
            action="?/deleteForm"
            use:enhance={() => {
              return async ({ update }) => {
                await update();
              };
            }}
          >
            <input type="hidden" name="id" value={f.id} />
            <button
              type="submit"
              class="rounded px-2 py-1 text-xs text-red-500 hover:bg-red-50"
              onclick={(e) => {
                if (!confirm(`"${f.name}" 양식을 삭제하시겠습니까?`)) {
                  e.preventDefault();
                }
              }}
            >
              삭제
            </button>
          </form>
        </li>
      {/each}
    </ul>
  {/if}
</div>
