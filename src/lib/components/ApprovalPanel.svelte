<script lang="ts">
  import { enhance } from '$app/forms';

  type Props = {
    canApprove: boolean;
    canAgree?: boolean;
    canWithdraw: boolean;
    canComment: boolean;
    isProxyApproval?: boolean;
  };

  let {
    canApprove,
    canAgree = false,
    canWithdraw,
    canComment,
    isProxyApproval = false
  }: Props = $props();

  let approveComment = $state('');
  let agreeComment = $state('');
  let disagreeReason = $state('');
  let showDisagreeModal = $state(false);
  let rejectReason = $state('');
  let withdrawReason = $state('');
  let commentText = $state('');

  let showRejectModal = $state(false);
  let showWithdrawBox = $state(false);
  let submitting = $state(false);
</script>

<div class="flex flex-col gap-4">
  {#if canApprove}
    <section class="rounded-lg border bg-white p-4">
      <h3 class="mb-3 text-sm font-semibold">
        {isProxyApproval ? '대리 결재 처리' : '결재 처리'}
      </h3>
      {#if isProxyApproval}
        <p class="mb-2 rounded bg-orange-50 px-3 py-2 text-xs text-orange-700">
          원 승인자의 부재로 대리 승인이 가능합니다. 승인 기록에 대리 표시가 남습니다.
        </p>
      {/if}
      <textarea
        bind:value={approveComment}
        placeholder="코멘트 (선택)"
        rows="2"
        class="w-full rounded border px-3 py-2 text-sm"
      ></textarea>
      <div class="mt-2 flex gap-2">
        <form
          method="POST"
          action="?/approve"
          class="flex-1"
          use:enhance={({ formData }) => {
            formData.set('comment', approveComment);
            submitting = true;
            return async ({ update }) => {
              await update();
              approveComment = '';
              submitting = false;
            };
          }}
        >
          <button
            type="submit"
            disabled={submitting}
            class="w-full rounded px-4 py-2 text-sm font-medium text-white disabled:opacity-50 {isProxyApproval
              ? 'bg-orange-600 hover:bg-orange-700'
              : 'bg-green-600 hover:bg-green-700'}"
          >
            {submitting ? '처리 중…' : isProxyApproval ? '대리 승인' : '승인'}
          </button>
        </form>
        <button
          type="button"
          onclick={() => (showRejectModal = true)}
          disabled={submitting}
          class="flex-1 rounded border border-red-300 px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-50 disabled:opacity-50"
        >
          반려
        </button>
      </div>
    </section>
  {/if}

  {#if canAgree}
    <section class="rounded-lg border bg-white p-4">
      <h3 class="mb-3 text-sm font-semibold">합의 처리</h3>
      <textarea bind:value={agreeComment} placeholder="코멘트 (선택)" rows="2" class="w-full rounded border px-3 py-2 text-sm"></textarea>
      <div class="mt-2 flex gap-2">
        <form method="POST" action="?/agree" class="flex-1" use:enhance={({ formData }) => {
          formData.set('comment', agreeComment);
          submitting = true;
          return async ({ update }) => { await update(); agreeComment = ''; submitting = false; };
        }}>
          <button type="submit" disabled={submitting} class="w-full rounded bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50">
            {submitting ? '처리 중…' : '동의'}
          </button>
        </form>
        <button type="button" onclick={() => showDisagreeModal = true} disabled={submitting} class="flex-1 rounded border border-red-300 px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-50 disabled:opacity-50">
          부동의
        </button>
      </div>
    </section>

    {#if showDisagreeModal}
      <section class="rounded-lg border border-red-200 bg-red-50 p-4">
        <h3 class="mb-2 text-sm font-semibold text-red-800">부동의 사유</h3>
        <form method="POST" action="?/disagree" use:enhance={({ formData, cancel }) => {
          if (!disagreeReason.trim()) { cancel(); return; }
          formData.set('comment', disagreeReason);
          submitting = true;
          return async ({ update }) => { await update(); disagreeReason = ''; showDisagreeModal = false; submitting = false; };
        }}>
          <textarea bind:value={disagreeReason} placeholder="부동의 사유를 입력하세요 (필수)" rows="3" required class="w-full rounded border px-3 py-2 text-sm"></textarea>
          <div class="mt-2 flex gap-2">
            <button type="submit" disabled={submitting || !disagreeReason.trim()} class="rounded bg-red-600 px-4 py-2 text-sm text-white disabled:opacity-50">부동의 확인</button>
            <button type="button" onclick={() => showDisagreeModal = false} class="rounded border px-4 py-2 text-sm">취소</button>
          </div>
        </form>
      </section>
    {/if}
  {/if}

  {#if canWithdraw}
    <section class="rounded-lg border bg-white p-4">
      <h3 class="mb-3 text-sm font-semibold">회수</h3>
      {#if !showWithdrawBox}
        <button
          type="button"
          onclick={() => (showWithdrawBox = true)}
          class="rounded border px-3 py-1.5 text-sm hover:bg-gray-50"
        >
          문서 회수
        </button>
      {:else}
        <form
          method="POST"
          action="?/withdraw"
          use:enhance={({ formData }) => {
            formData.set('reason', withdrawReason);
            submitting = true;
            return async ({ update }) => {
              await update();
              withdrawReason = '';
              showWithdrawBox = false;
              submitting = false;
            };
          }}
        >
          <textarea
            bind:value={withdrawReason}
            placeholder="회수 사유 (선택)"
            rows="2"
            class="w-full rounded border px-3 py-2 text-sm"
          ></textarea>
          <div class="mt-2 flex gap-2">
            <button
              type="submit"
              disabled={submitting}
              class="rounded bg-gray-700 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
            >
              {submitting ? '회수 중…' : '회수 확정'}
            </button>
            <button
              type="button"
              onclick={() => (showWithdrawBox = false)}
              class="rounded border px-4 py-2 text-sm hover:bg-gray-50"
            >
              취소
            </button>
          </div>
        </form>
      {/if}
    </section>
  {/if}

  {#if canComment}
    <section class="rounded-lg border bg-white p-4">
      <h3 class="mb-3 text-sm font-semibold">코멘트</h3>
      <form
        method="POST"
        action="?/comment"
        use:enhance={({ formData }) => {
          formData.set('comment', commentText);
          submitting = true;
          return async ({ update }) => {
            await update();
            commentText = '';
            submitting = false;
          };
        }}
      >
        <textarea
          bind:value={commentText}
          placeholder="코멘트 작성"
          rows="2"
          class="w-full rounded border px-3 py-2 text-sm"
        ></textarea>
        <button
          type="submit"
          disabled={submitting || !commentText.trim()}
          class="mt-2 rounded bg-gray-100 px-4 py-2 text-sm font-medium hover:bg-gray-200 disabled:opacity-50"
        >
          {submitting ? '전송 중…' : '코멘트 추가'}
        </button>
      </form>
    </section>
  {/if}
</div>

{#if showRejectModal}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/30"
    role="dialog"
    aria-modal="true"
  >
    <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">반려 사유</h3>
        <button
          type="button"
          class="text-gray-400 hover:text-gray-600"
          onclick={() => (showRejectModal = false)}>✕</button
        >
      </div>
      <form
        method="POST"
        action="?/reject"
        use:enhance={({ formData, cancel }) => {
          if (!rejectReason.trim()) {
            cancel();
            return;
          }
          formData.set('comment', rejectReason);
          submitting = true;
          return async ({ update }) => {
            await update();
            rejectReason = '';
            showRejectModal = false;
            submitting = false;
          };
        }}
      >
        <textarea
          bind:value={rejectReason}
          required
          rows="4"
          placeholder="반려 사유를 입력하세요 (필수)"
          class="w-full rounded border px-3 py-2 text-sm"
        ></textarea>
        <div class="mt-4 flex justify-end gap-2">
          <button
            type="button"
            onclick={() => (showRejectModal = false)}
            class="rounded border px-4 py-2 text-sm hover:bg-gray-50"
          >
            취소
          </button>
          <button
            type="submit"
            disabled={submitting || !rejectReason.trim()}
            class="rounded bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"
          >
            {submitting ? '처리 중…' : '반려 확정'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}
