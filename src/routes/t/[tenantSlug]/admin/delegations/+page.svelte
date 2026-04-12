<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();

  const baseHref = $derived(`/t/${data.currentTenant.slug}/admin/delegations`);

  function formatAmount(n: number | null): string {
    if (n === null) return '무제한';
    return new Intl.NumberFormat('ko-KR').format(n) + '원';
  }

  function formatDate(s: string | null): string {
    if (!s) return '상시';
    return new Date(s).toLocaleDateString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });
  }

  function isActive(from: string, to: string | null): boolean {
    const now = Date.now();
    if (new Date(from).getTime() > now) return false;
    if (to && new Date(to).getTime() <= now) return false;
    return true;
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex items-center justify-between">
    <div>
      <h2 class="text-lg font-semibold">전결 규칙</h2>
      <p class="mt-1 text-xs text-gray-500">
        위임자의 결재 단계를 상신 시점에 자동으로 전결 처리하는 규칙입니다.
      </p>
    </div>
    <a
      href={`${baseHref}/new`}
      class="rounded bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
    >
      + 새 전결 규칙
    </a>
  </div>

  {#if form?.error}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
      {form.error}
    </p>
  {/if}

  {#if data.rules.length === 0}
    <div class="rounded-lg border bg-white p-12 text-center text-sm text-gray-500">
      등록된 전결 규칙이 없습니다. "+ 새 전결 규칙" 으로 추가하세요.
    </div>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each data.rules as r (r.id)}
        {@const active = isActive(r.effective_from, r.effective_to)}
        <li class="rounded border bg-white px-4 py-3">
          <div class="flex items-start gap-3">
            <a
              href={`${baseHref}/${r.id}`}
              class="min-w-0 flex-1 hover:underline"
            >
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-medium">{r.delegator.display_name}</span>
                <span class="text-gray-400">→</span>
                <span class="font-medium">{r.delegate.display_name}</span>
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
                  <span class="text-gray-400">양식</span>
                  {r.form ? `${r.form.name} (${r.form.code})` : '전 양식'}
                </span>
                <span>
                  <span class="text-gray-400">한도</span>
                  {formatAmount(r.amount_limit)}
                </span>
                <span>
                  <span class="text-gray-400">기간</span>
                  {formatDate(r.effective_from)} ~ {formatDate(r.effective_to)}
                </span>
              </div>
            </a>

            <form
              method="POST"
              action="?/deleteRule"
              use:enhance={() => {
                return async ({ update }) => {
                  await update();
                };
              }}
            >
              <input type="hidden" name="id" value={r.id} />
              <button
                type="submit"
                class="rounded px-2 py-1 text-xs text-red-500 hover:bg-red-50"
                onclick={(e) => {
                  if (
                    !confirm(
                      `${r.delegator.display_name} → ${r.delegate.display_name} 전결 규칙을 삭제하시겠습니까?`
                    )
                  ) {
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
