<script lang="ts">
  import { enhance } from '$app/forms';

  type Props = {
    canApprove: boolean;
    canWithdraw: boolean;
    canComment: boolean;
  };

  let { canApprove, canWithdraw, canComment }: Props = $props();

  let approveComment = $state('');
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
      <h3 class="mb-3 text-sm font-semibold">결재 처리</h3>
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
            class="w-full rounded bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
          >
            {submitting ? '처리 중…' : '승인'}
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
