<script lang="ts">
  /**
   * StampLine — 한국형 가로 도장 결재선 시각화 (v2.3 M1).
   * 기안 프리뷰 + 문서 상세 양쪽에서 사용.
   */
  export type StampStep = {
    name: string;
    title: string;
    status: 'pending' | 'approved' | 'rejected' | 'skipped';
    stepType: 'approval' | 'agreement' | 'reference';
  };

  type Props = {
    steps: StampStep[];
    drafterName: string;
  };

  let { steps, drafterName }: Props = $props();

  const stepTypeLabel: Record<string, string> = {
    approval: '결재',
    agreement: '합의',
    reference: '참조'
  };

  const statusLabel: Record<string, string> = {
    approved: '승인',
    rejected: '반려',
    skipped: '생략',
    pending: '대기'
  };
</script>

<div class="overflow-x-auto">
  <div class="inline-flex text-center">
    <!-- 기안자 -->
    <div class="flex flex-col items-center border px-3 py-1.5 bg-blue-50">
      <span class="text-[10px] text-gray-500">기안</span>
      <span class="text-xs font-medium">{drafterName}</span>
      <span class="text-[10px] text-blue-500">기안</span>
    </div>
    <!-- 결재 단계들 -->
    {#each steps as step, i (i)}
      <div class="flex flex-col items-center border-t border-b border-r px-3 py-1.5"
           class:bg-green-50={step.status === 'approved'}
           class:bg-red-50={step.status === 'rejected'}
           class:bg-gray-50={step.status === 'skipped'}>
        <span class="text-[10px] text-gray-500">{stepTypeLabel[step.stepType] ?? step.stepType}</span>
        <span class="text-xs font-medium">{step.name}</span>
        <span class="text-[10px] text-gray-400">{step.title}</span>
        <span class="mt-0.5 text-[10px]"
              class:text-green-600={step.status === 'approved'}
              class:text-red-600={step.status === 'rejected'}
              class:text-gray-400={step.status === 'pending' || step.status === 'skipped'}>
          {statusLabel[step.status] ?? step.status}
        </span>
      </div>
    {/each}
  </div>
</div>
