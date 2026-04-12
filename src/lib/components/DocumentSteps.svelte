<script lang="ts">
  import type { StepStatus, StepType } from '$lib/types/approval';

  // 읽기 전용 step 리스트. /approval/documents/[id] 에서 ApprovalLine 아래에 배치.
  //
  // v1.2 M16b: group_order 기준 grouping + 병렬 배지 + 서명이미지 embed.
  // 동일 group_order 에 속한 step 들은 "병렬" 로 표시.
  // signature_url 이 있는 approved step 에는 서명 PNG 를 inline 렌더.

  export type DocumentStepRow = {
    id: string;
    step_index: number;
    group_order: number;
    step_type: StepType;
    approver_user_id: string;
    approver_name: string;
    approver_email: string;
    status: StepStatus;
    acted_at: string | null;
    comment: string | null;
    acted_by_proxy_user_id: string | null;
    signature_url: string | null;
  };

  type Props = {
    steps: DocumentStepRow[];
  };

  let { steps }: Props = $props();

  // group_order 기준 grouping + 그룹 내 step_index 정렬 유지
  const grouped = $derived.by(() => {
    const map = new Map<number, DocumentStepRow[]>();
    for (const s of steps) {
      const arr = map.get(s.group_order) ?? [];
      arr.push(s);
      map.set(s.group_order, arr);
    }
    return Array.from(map.entries())
      .sort(([a], [b]) => a - b)
      .map(([groupOrder, groupSteps]) => ({
        groupOrder,
        groupSteps: groupSteps.sort((a, b) => a.step_index - b.step_index)
      }));
  });

  // v1.1 M11: delegation skipped → comment '[전결]' prefix
  function isDelegated(s: DocumentStepRow): boolean {
    return s.status === 'skipped' && (s.comment ?? '').startsWith('[전결]');
  }

  function isProxyActed(s: DocumentStepRow): boolean {
    return s.acted_by_proxy_user_id !== null;
  }

  const STATUS_LABEL: Record<StepStatus, string> = {
    pending: '대기',
    approved: '승인',
    rejected: '반려',
    skipped: '건너뜀'
  };
</script>

<ul class="mt-4 flex flex-col gap-3">
  {#each grouped as { groupOrder, groupSteps } (groupOrder)}
    <li class="rounded-lg border bg-gray-50 p-3">
      <div class="mb-2 flex items-center gap-2 text-xs text-gray-500">
        <span class="font-semibold">그룹 {groupOrder + 1}</span>
        {#if groupSteps.length > 1}
          <span class="rounded bg-blue-100 px-2 py-0.5 text-blue-700">
            병렬 ({groupSteps.length}명)
          </span>
        {/if}
      </div>
      <ul class="flex flex-col gap-2">
        {#each groupSteps as s (s.id)}
          <li class="rounded border bg-white px-3 py-2 text-sm">
            <div class="flex flex-wrap items-center gap-2">
              <span class="w-6 text-gray-500">{s.step_index + 1}</span>
              <span class="min-w-0 flex-1 truncate font-medium">{s.approver_name}</span>

              {#if isDelegated(s)}
                <span class="rounded bg-purple-100 px-2 py-0.5 text-xs text-purple-700">
                  전결
                </span>
              {/if}
              {#if isProxyActed(s)}
                <span class="rounded bg-orange-100 px-2 py-0.5 text-xs text-orange-700">
                  대리
                </span>
              {/if}

              <span
                class="rounded px-2 py-0.5 text-xs"
                class:bg-yellow-100={s.status === 'pending'}
                class:text-yellow-800={s.status === 'pending'}
                class:bg-green-100={s.status === 'approved'}
                class:text-green-800={s.status === 'approved'}
                class:bg-red-100={s.status === 'rejected'}
                class:text-red-800={s.status === 'rejected'}
                class:bg-gray-200={s.status === 'skipped'}
                class:text-gray-600={s.status === 'skipped'}
              >
                {STATUS_LABEL[s.status]}
              </span>

              {#if s.signature_url && s.status === 'approved'}
                <img
                  src={s.signature_url}
                  alt="{s.approver_name} 서명"
                  class="h-8 w-auto border border-gray-200"
                />
              {/if}
            </div>
            {#if s.comment}
              <div class="mt-1 whitespace-pre-wrap pl-8 text-xs text-gray-600">
                {s.comment}
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    </li>
  {/each}
</ul>
