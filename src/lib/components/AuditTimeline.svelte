<script lang="ts">
  import type { AuditAction } from '$lib/types/approval';

  type AuditEntry = {
    id: string;
    action: AuditAction;
    payload: Record<string, unknown>;
    created_at: string;
    actorName: string;
    actorEmail: string;
  };

  type Props = {
    audits: AuditEntry[];
  };

  let { audits }: Props = $props();

  const actionLabel: Record<AuditAction, string> = {
    draft_saved: '임시저장',
    submit: '상신',
    approve: '승인',
    reject: '반려',
    withdraw: '회수',
    comment: '코멘트',
    // v1.1 M11~M14
    delegated: '전결',
    approved_by_proxy: '대리 승인',
    submitted_post_facto: '후결 상신',
    auto_delegated: '자동 위임',
    agreed: '합의 동의',
    disagreed: '합의 부동의'
  };

  const actionColor: Record<AuditAction, string> = {
    draft_saved: 'text-gray-600',
    submit: 'text-blue-600',
    approve: 'text-green-600',
    reject: 'text-red-600',
    withdraw: 'text-gray-600',
    comment: 'text-gray-700',
    // v1.1 M11~M14
    delegated: 'text-purple-600',
    approved_by_proxy: 'text-orange-600',
    submitted_post_facto: 'text-orange-600',
    auto_delegated: 'text-purple-600',
    agreed: 'text-green-600',
    disagreed: 'text-red-600'
  };

  function fmt(iso: string): string {
    return new Date(iso).toLocaleString('ko-KR', {
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function extractMessage(entry: AuditEntry): string | null {
    const p = entry.payload;
    if (p.comment && typeof p.comment === 'string') return p.comment;
    if (p.reason && typeof p.reason === 'string') return p.reason;
    return null;
  }
</script>

<section>
  <h3 class="mb-2 text-sm font-semibold text-gray-700">이력</h3>
  {#if audits.length === 0}
    <p class="text-xs text-gray-500">이력 없음</p>
  {:else}
    <ol class="flex flex-col gap-2">
      {#each audits as entry (entry.id)}
        {@const msg = extractMessage(entry)}
        <li class="flex gap-3 rounded border bg-white px-3 py-2">
          <span class="w-14 shrink-0 text-xs font-semibold {actionColor[entry.action]}">
            {actionLabel[entry.action]}
          </span>
          <div class="min-w-0 flex-1">
            <div class="text-sm">
              {entry.actorName}
              <span class="text-xs text-gray-400">· {entry.actorEmail}</span>
            </div>
            {#if msg}
              <div class="mt-1 whitespace-pre-wrap text-xs text-gray-600">{msg}</div>
            {/if}
          </div>
          <span class="shrink-0 text-xs text-gray-400">{fmt(entry.created_at)}</span>
        </li>
      {/each}
    </ol>
  {/if}
</section>
