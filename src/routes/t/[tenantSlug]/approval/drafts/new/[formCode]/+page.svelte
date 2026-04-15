<script lang="ts">
  import { enhance } from '$app/forms';
  import { untrack } from 'svelte';
  import FormRenderer from '$lib/components/FormRenderer.svelte';
  import ApprovalLine from '$lib/components/ApprovalLine.svelte';
  import StampLine from '$lib/components/StampLine.svelte';
  import type { StampStep } from '$lib/components/StampLine.svelte';
  import OrgTreePicker from '$lib/components/OrgTreePicker.svelte';
  import type { ApprovalLineItem } from '$lib/types/approval';
  import type { UploadedAttachment } from '$lib/client/uploadAttachment';

  let { data, form } = $props();

  // Form 콘텐츠 (임시저장 불러오기 시 초기값)
  let content = $state<Record<string, unknown>>(
    untrack(() => data.draftContent ?? {})
  );

  // 결재선
  let approvalLine = $state<ApprovalLineItem[]>(
    untrack(() => [...data.form.defaultApprovalLine])
  );

  // 문서 설정
  let urgency = $state('일반');
  let isPostFacto = $state(false);
  let postFactoReason = $state('');
  let retentionPeriod = $state('5년');
  let securityLevel = $state('일반');

  // 임시저장된 문서 ID (불러오기 시 초기값)
  let documentId = $state<string | null>(data.loadedDocumentId ?? null);

  // 결재선 프리뷰
  let previewInfo = $state<{ approvers: { userId: string; displayName: string; departmentName: string | null; jobTitleName: string | null; stepType: string }[]; ruleName: string | null; error: string | null } | null>(null);
  let previewError = $state<string | null>(null);
  let resolving = $state(false);

  // hidden 필드 추적
  let hiddenIds = $state<Set<string>>(new Set());

  // 저장 피드백
  let saveMessage = $state<string | null>(null);

  // 제출 상태
  let submittingSave = $state(false);
  let submittingSubmit = $state(false);

  // v2.3 M2: OrgTreePicker
  let showOrgPicker = $state(false);

  // 즐겨찾기 저장 다이얼로그
  let showFavDialog = $state(false);
  let favName = $state('');

  // 결재선 요약 텍스트
  function lineSummary(line: ApprovalLineItem[]): string {
    return line.map((item) => {
      const m = data.members.find((p) => p.id === item.userId);
      return m?.displayName ?? '(알 수 없음)';
    }).join(' → ');
  }

  // 결재선 적용 (groupOrder 보장)
  function applyLine(line: ApprovalLineItem[]) {
    approvalLine = line.map((item, idx) => ({ ...item, groupOrder: item.groupOrder ?? idx }));
    previewInfo = null;
    previewError = null;
  }

  function collectAttachmentIds(): string[] {
    const ids: string[] = [];
    for (const field of data.form.schema.fields) {
      if (field.type === 'attachment') {
        const items = content[field.id] as UploadedAttachment[] | undefined;
        if (items && items.length > 0) {
          for (const a of items) ids.push(a.id);
        }
      }
    }
    return ids;
  }
</script>

<div class="flex flex-col gap-5">
  <!-- 헤더 -->
  <div>
    <h1 class="text-2xl font-bold">{data.form.name}</h1>
    {#if data.form.description}
      <p class="mt-1 text-sm text-gray-500">{data.form.description}</p>
    {/if}
  </div>

  <!-- ═══ 1. 문서 설정 (긴급도 + 후결) ═══════════ -->
  <section class="rounded-lg border bg-white p-4">
    <h2 class="mb-3 text-sm font-semibold text-gray-700">문서 설정</h2>
    <div class="flex flex-wrap items-start gap-6">
      <!-- 긴급도 -->
      <label class="flex items-center gap-2">
        <span class="text-sm text-gray-600">긴급도</span>
        <select bind:value={urgency} class="rounded border px-2 py-1 text-sm">
          <option value="일반">일반</option>
          <option value="긴급">긴급</option>
        </select>
      </label>
      {#if urgency === '긴급'}
        <span class="rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">긴급 문서</span>
      {/if}

      <!-- 보관기한 -->
      <label class="flex items-center gap-2">
        <span class="text-sm text-gray-600">보관기한</span>
        <select bind:value={retentionPeriod} class="rounded border px-2 py-1 text-sm">
          <option value="1년">1년</option>
          <option value="3년">3년</option>
          <option value="5년">5년</option>
          <option value="10년">10년</option>
          <option value="영구">영구</option>
        </select>
      </label>

      <!-- 보안등급 -->
      <label class="flex items-center gap-2">
        <span class="text-sm text-gray-600">보안등급</span>
        <select bind:value={securityLevel} class="rounded border px-2 py-1 text-sm">
          <option value="일반">일반</option>
          <option value="대외비">대외비</option>
          <option value="비밀">비밀</option>
        </select>
      </label>

      <!-- 후결 -->
      <label class="flex items-center gap-2">
        <input type="checkbox" bind:checked={isPostFacto} class="h-4 w-4 rounded border-gray-300" />
        <span class="text-sm text-gray-600">후결 (사후 결재)</span>
      </label>
    </div>

    {#if isPostFacto}
      <div class="mt-3">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">후결 사유 <span class="text-red-500">*</span></span>
          <textarea bind:value={postFactoReason} rows="2" maxlength="1000" placeholder="긴급 상황 또는 사후 결재 사유" class="rounded border px-3 py-2 text-sm"></textarea>
        </label>
        {#if form?.errors?.fields?.reason}
          <p class="mt-1 text-xs text-red-600">{form.errors.fields.reason}</p>
        {/if}
      </div>
    {/if}
  </section>

  <!-- ═══ 2. 결재선 선택 (즐겨찾기 > 추천 > 자동) ═══ -->
  <section class="rounded-lg border bg-white p-4">
    <div class="mb-3 flex items-center justify-between">
      <h2 class="text-sm font-semibold text-gray-700">결재선</h2>
      {#if approvalLine.length > 0}
        <button type="button" onclick={() => { showFavDialog = !showFavDialog; }} class="text-xs text-blue-600 hover:underline">
          ★ 즐겨찾기 저장
        </button>
      {/if}
    </div>

    <!-- 즐겨찾기 저장 다이얼로그 -->
    {#if showFavDialog}
      <form method="POST" action="?/saveFavorite" class="mb-3 flex items-center gap-2 rounded border border-blue-200 bg-blue-50 p-2" use:enhance={() => {
        return async ({ update }) => { await update({ reset: false }); showFavDialog = false; favName = ''; };
      }}>
        <input type="hidden" name="formId" value={data.form.id} />
        <input type="hidden" name="lineJson" value={JSON.stringify(approvalLine)} />
        <input type="text" name="favName" bind:value={favName} placeholder="즐겨찾기 이름" required class="flex-1 rounded border px-2 py-1 text-sm" />
        <button type="submit" class="rounded bg-blue-600 px-3 py-1 text-sm text-white">저장</button>
        <button type="button" onclick={() => showFavDialog = false} class="text-xs text-gray-500">취소</button>
      </form>
    {/if}

    <!-- 즐겨찾기 목록 -->
    {#if data.favorites.length > 0}
      <div class="mb-3">
        <p class="mb-1 text-xs font-medium text-gray-500">★ 즐겨찾기</p>
        <div class="flex flex-wrap gap-1">
          {#each data.favorites as fav (fav.id)}
            <div class="flex items-center gap-1 rounded border bg-gray-50 px-2 py-1 text-xs">
              <button type="button" onclick={() => applyLine(fav.lineJson)} class="text-blue-600 hover:underline">{fav.name}</button>
              <span class="text-gray-400">({lineSummary(fav.lineJson)})</span>
              <form method="POST" action="?/removeFavorite" class="inline" use:enhance={() => {
                return async ({ update }) => { await update({ reset: false }); };
              }}>
                <input type="hidden" name="favId" value={fav.id} />
                <button type="submit" class="text-gray-400 hover:text-red-500">×</button>
              </form>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- 추천 템플릿 -->
    {#if data.templates.length > 0}
      <div class="mb-3">
        <p class="mb-1 text-xs font-medium text-gray-500">📋 추천 결재선</p>
        <div class="flex flex-wrap gap-1">
          {#each data.templates as tpl (tpl.id)}
            <button type="button" onclick={() => applyLine(tpl.lineJson)}
              class="flex items-center gap-1 rounded border px-2 py-1 text-xs hover:bg-gray-50"
              class:border-blue-300={tpl.isDefault}
              class:bg-blue-50={tpl.isDefault}>
              {#if tpl.isDefault}<span class="text-blue-500">⭐</span>{/if}
              {tpl.name}
              <span class="text-gray-400">({lineSummary(tpl.lineJson)})</span>
            </button>
          {/each}
        </div>
      </div>
    {/if}

    <!-- 자동 구성 -->
    <div class="mb-3 flex items-center gap-2">
      <form method="POST" action="?/resolvePreview" use:enhance={({ formData }) => {
        formData.set('formId', data.form.id);
        formData.set('content', JSON.stringify(content));
        resolving = true;
        return async ({ result, update }) => {
          if (result.type === 'success' && result.data?.preview) {
            const preview = result.data.preview as typeof previewInfo;
            if (preview?.error) {
              previewError = preview.error; previewInfo = null;
            } else if (preview) {
              approvalLine = preview.approvers.map((a, idx) => ({ userId: a.userId, stepType: a.stepType as 'approval' | 'agreement' | 'reference', groupOrder: idx }));
              previewInfo = preview; previewError = null;
            }
          }
          resolving = false;
          await update({ reset: false });
        };
      }}>
        <button type="submit" disabled={resolving} class="rounded border bg-gray-50 px-3 py-1 text-xs text-gray-600 hover:bg-gray-100 disabled:opacity-50">
          {resolving ? '구성 중…' : '🤖 자동 구성'}
        </button>
      </form>
      {#if approvalLine.length > 0}
        <button type="button" onclick={() => { approvalLine = []; previewInfo = null; previewError = null; }} class="text-xs text-gray-400 hover:underline">초기화</button>
      {/if}
    </div>

    {#if previewInfo && !previewInfo.error}
      <div class="mb-3 rounded border border-blue-200 bg-blue-50 px-3 py-1.5 text-xs text-blue-700">
        규칙 "{previewInfo.ruleName ?? '기본'}" 기반 — 수동 편집 가능
      </div>
    {/if}
    {#if previewError}
      <p class="mb-3 text-xs text-amber-600">{previewError}</p>
    {/if}

    <!-- StampLine 프리뷰 (v2.3 M1 — 컴포넌트) -->
    {#if approvalLine.length > 0}
      {@const stampSteps: StampStep[] = approvalLine.map((item) => {
        const m = data.members.find(p => p.id === item.userId);
        return { name: m?.displayName ?? '(알 수 없음)', title: m?.jobTitle ?? '', status: 'pending' as const, stepType: item.stepType };
      })}
      <div class="mb-3">
        <StampLine steps={stampSteps} drafterName="나" />
      </div>
    {/if}

    <!-- v2.3 M2: OrgTreePicker 토글 -->
    {#if showOrgPicker}
      <div class="mb-3">
        <OrgTreePicker
          departments={data.departments ?? []}
          members={data.members.map(m => ({ id: m.id, displayName: m.displayName, email: m.email, departmentId: m.departmentId, jobTitle: m.jobTitle }))}
          onSelect={(m) => {
            if (!approvalLine.some(item => item.userId === m.id)) {
              // ApproverPicker 경로와 동일하게 명시 groupOrder 부여 (항상 새 그룹).
              // groupOrder 없이 추가 후 submit 시 idx fallback 을 쓰면 ApproverPicker
              // 로 추가한 항목들과 섞여 [0, 0, 2] 같은 띄엄띄엄 배열이 생기고
              // refine 실패(상신 불가) 로 이어짐.
              const maxGroup = approvalLine.reduce(
                (max, i, idx) => Math.max(max, i.groupOrder ?? idx),
                -1
              );
              approvalLine = [
                ...approvalLine,
                { userId: m.id, stepType: 'approval', groupOrder: maxGroup + 1 }
              ];
            }
          }}
          onClose={() => showOrgPicker = false}
        />
      </div>
    {/if}

    <!-- 결재선 편집 -->
    <div class="mb-2 flex items-center gap-2">
      <button type="button" onclick={() => showOrgPicker = !showOrgPicker} class="text-xs text-blue-600 hover:underline">
        {showOrgPicker ? '조직도 닫기' : '조직도에서 선택'}
      </button>
    </div>
    <ApprovalLine line={approvalLine} members={data.members} editable onChange={(next) => (approvalLine = next)} />
  </section>

  <!-- ═══ 3. 내용 (FormRenderer) ═══════════════ -->
  <section class="rounded-lg border bg-white p-6">
    <h2 class="mb-4 text-sm font-semibold text-gray-700">내용</h2>
    <FormRenderer
      schema={data.form.schema}
      tenantId={data.currentTenant.id}
      value={content}
      errors={form?.errors?.fields ?? {}}
      onChange={(next) => (content = next)}
      onHiddenChange={(ids) => (hiddenIds = ids)}
    />
  </section>

  <!-- 에러 -->
  {#if form?.errors?.form}
    <p class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">{form.errors.form}</p>
  {/if}

  <!-- ═══ 4. 액션 버튼 ═══════════════════════ -->
  <div class="flex items-center justify-end gap-2">
    <form method="POST" action="?/saveDraft" use:enhance={({ formData }) => {
      formData.set('formId', data.form.id);
      formData.set('content', JSON.stringify(content));
      if (documentId) formData.set('documentId', documentId);
      submittingSave = true;
      saveMessage = null;
      return async ({ result, update }) => {
        if (result.type === 'success') {
          const d = result.data as Record<string, unknown> | undefined;
          if (d?.documentId) documentId = d.documentId as string;
          saveMessage = '임시저장되었습니다.';
          setTimeout(() => saveMessage = null, 3000);
        } else {
          saveMessage = '임시저장에 실패했습니다.';
        }
        await update({ reset: false });
        submittingSave = false;
      };
    }}>
      <button type="submit" disabled={submittingSave || submittingSubmit} class="rounded border px-4 py-2 text-sm hover:bg-gray-50 disabled:opacity-50">
        {submittingSave ? '저장 중…' : documentId ? '임시저장 (업데이트)' : '임시저장'}
      </button>
    </form>
    {#if saveMessage}
      <span class="text-xs text-green-600">{saveMessage}</span>
    {/if}

    <form method="POST" action={isPostFacto ? '?/submitPostFacto' : '?/submit'} use:enhance={({ formData, cancel }) => {
      if (isPostFacto && postFactoReason.trim().length === 0) { cancel(); return; }
      const filtered = { ...content };
      for (const id of hiddenIds) delete filtered[id];
      formData.set('formId', data.form.id);
      formData.set('content', JSON.stringify(filtered));
      // groupOrder 보장 (undefined → index 할당)
      const normalizedLine = approvalLine.map((item, idx) => ({
        ...item,
        groupOrder: item.groupOrder ?? idx
      }));
      formData.set('approvalLine', JSON.stringify(normalizedLine));
      formData.set('attachmentIds', JSON.stringify(collectAttachmentIds()));
      formData.set('urgency', urgency);
      formData.set('retentionPeriod', retentionPeriod);
      formData.set('securityLevel', securityLevel);
      if (isPostFacto) { formData.set('reason', postFactoReason); }
      else if (documentId) { formData.set('documentId', documentId); }
      // eslint-disable-next-line no-console
      console.log('[rigel:submit]', { approvalLine: normalizedLine, isPostFacto, urgency });
      submittingSubmit = true;
      return async ({ result, update }) => {
        // 사일런트 실패 방지용 로깅. 실패 시 콘솔 + alert 로 즉시 확인 가능.
        // eslint-disable-next-line no-console
        console.log('[rigel:submit:result]', result);
        if (result.type === 'failure') {
          const data = result.data as { errors?: { form?: string | null; fields?: Record<string, string> } } | undefined;
          const formMsg = data?.errors?.form;
          const fieldMsgs = Object.entries(data?.errors?.fields ?? {})
            .map(([k, v]) => `${k}: ${v}`)
            .join('\n');
          const composed = [formMsg, fieldMsgs].filter(Boolean).join('\n') || `상신 실패 (status ${result.status})`;
          // eslint-disable-next-line no-console
          console.warn('[rigel:submit:fail]', composed, data);
          alert(`상신 실패:\n${composed}`);
        } else if (result.type === 'error') {
          // eslint-disable-next-line no-console
          console.error('[rigel:submit:error]', result.error);
          alert(`상신 오류:\n${result.error?.message ?? '알 수 없는 에러'}`);
        }
        await update();
        submittingSubmit = false;
      };
    }}>
      <button type="submit"
        disabled={submittingSubmit || submittingSave || approvalLine.length === 0 || (isPostFacto && !postFactoReason.trim())}
        class="rounded px-6 py-2 text-sm text-white disabled:opacity-50 {isPostFacto ? 'bg-orange-600 hover:bg-orange-700' : urgency === '긴급' ? 'bg-red-600 hover:bg-red-700' : 'bg-blue-600 hover:bg-blue-700'}">
        {submittingSubmit ? '상신 중…' : isPostFacto ? '후결 상신' : urgency === '긴급' ? '긴급 상신' : '상신'}
      </button>
    </form>
  </div>
</div>
