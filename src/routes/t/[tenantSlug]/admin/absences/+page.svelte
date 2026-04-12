<script lang="ts">
  import { enhance } from '$app/forms';
  import { ABSENCE_TYPE_LABELS } from '$lib/absenceTypes';

  let { data, form } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/admin/absences`);

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function isActive(from: string, to: string): boolean {
    const now = Date.now();
    return new Date(from).getTime() <= now && now <= new Date(to).getTime();
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <div>
      <h2 class="text-lg font-semibold">부재 (대결 설정)</h2>
      <p class="mt-1 text-xs text-gray-500">
        부재 기간 동안 해당 사용자의 결재는 대리인이 승인할 수 있습니다.
      </p>
    </div>
    <a
      href={`${baseHref}/new`}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      + 새 부재 등록
    </a>
  </div>

  {#if form?.error}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {form.error}
    </p>
  {/if}

  {#if data.absences.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      등록된 부재가 없습니다.
    </div>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each data.absences as a (a.id)}
        {@const active = isActive(a.start_at, a.end_at)}
        <li class="rounded border bg-white px-4 py-3">
          <div class="flex items-start gap-3">
            <a href={`${baseHref}/${a.id}`} class="min-w-0 flex-1 hover:underline">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-medium">{a.user.display_name}</span>
                <span class="text-gray-400">→</span>
                <span class="font-medium">{a.delegate.display_name}</span>
                <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">
                  {ABSENCE_TYPE_LABELS[a.absence_type]}
                </span>
                {#if active}
                  <span class="rounded bg-green-100 px-2 py-0.5 text-xs text-green-700">
                    활성
                  </span>
                {:else}
                  <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">
                    비활성
                  </span>
                {/if}
              </div>
              <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-gray-600">
                <span>
                  <span class="text-gray-400">기간</span>
                  {formatDate(a.start_at)} ~ {formatDate(a.end_at)}
                </span>
                <span>
                  <span class="text-gray-400">범위</span>
                  {a.scope_form ? `${a.scope_form.name} (${a.scope_form.code})` : '전 결재'}
                </span>
              </div>
              {#if a.reason}
                <p class="mt-1 text-xs text-gray-500">사유: {a.reason}</p>
              {/if}
            </a>

            <form
              method="POST"
              action="?/deleteAbsence"
              use:enhance={() => {
                return async ({ update }) => {
                  await update();
                };
              }}
            >
              <input type="hidden" name="id" value={a.id} />
              <button
                type="submit"
                class="rounded px-2 py-1 text-xs text-red-500 hover:bg-red-50"
                onclick={(e) => {
                  if (!confirm(`${a.user.display_name}의 부재를 삭제하시겠습니까?`)) {
                    e.preventDefault();
                  }
                }}
              >
                삭제
              </button>
            </form>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>
