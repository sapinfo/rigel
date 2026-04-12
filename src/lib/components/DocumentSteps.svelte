<script lang="ts">
  import type { StepStatus, StepType } from '$lib/types/approval';

  // 읽기 전용 step 리스트. /approval/documents/[id] 에서 ApprovalLine 아래에 배치되어
  // 각 step 의 상태 / 코멘트 / 전결·대리 배지를 표시한다.
  //
  // v1.2 에서는 병렬결재 그룹 배지가 여기에 추가될 예정 (parallel_groups 도입 시).
  // 현재는 v1.1 의 순차 + 전결/대리만 표현.

  export type DocumentStepRow = {
    id: string;
    step_index: number;
    step_type: StepType;
    approver_user_id: string;
    approver_name: string;
    approver_email: string;
    status: StepStatus;
    acted_at: string | null;
    comment: string | null;
    acted_by_proxy_user_id: string | null;
  };

  type Props = {
    steps: DocumentStepRow[];
  };

  let { steps }: Props = $props();

  // v1.1 M11: delegation 으로 skipped 된 step 은 comment 가 '[전결]' 로 시작.
  // (0021_fn_submit_draft_v2.sql 참조 — audit 'delegated' + step.comment 초입 '[전결]')
  function isDelegated(s: DocumentStepRow): boolean {
    return s.status === 'skipped' && (s.comment ?? '').startsWith('[전결]');
  }

  // v1.1 M12: 대리 승인자가 있는 경우 acted_by_proxy_user_id != NULL.
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

<ul class="mt-4 flex flex-col gap-2">
  {#each steps as s (s.id)}
    <li class="rounded border bg-gray-50 px-3 py-2 text-sm">
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
      </div>
      {#if s.comment}
        <div class="mt-1 whitespace-pre-wrap pl-8 text-xs text-gray-600">{s.comment}</div>
      {/if}
    </li>
  {/each}
</ul>
