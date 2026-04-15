import type { PageServerLoad } from './$types';
import type { InboxTab, InboxCounts } from '$lib/types/approval';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { SupabaseClient } from '@supabase/supabase-js';

const VALID_TABS: InboxTab[] = ['pending', 'in_progress', 'completed', 'rejected', 'drafts'];

function parseTab(raw: string | null): InboxTab {
  if (raw && (VALID_TABS as string[]).includes(raw)) return raw as InboxTab;
  return 'pending';
}

/**
 * "현재 단계가 내 차례인" in_progress 문서 목록.
 * loadCounts.pending 과 loadDocumentsForTab('pending') 양쪽에서 재사용.
 */
async function loadPendingDocs(
  supabase: SupabaseClient,
  tenantId: string,
  userId: string
): Promise<DocRow[]> {
  // v1.2 M15 이후 approval_documents.current_step_index 는 group_order 포인터다
  // (0031_fn_advance_document.sql COMMENT 참조). step_index 로 비교하면 병렬 그룹이나
  // 결재선 배열 순서와 group_order 가 어긋난 문서에서 다음 그룹 결재자에게 문서가
  // 미리 보이는 버그(APP-20260415-0009)가 발생한다. group_order 기준으로 비교해야 맞다.
  const { data: steps } = await supabase
    .from('approval_steps')
    .select('document_id, group_order')
    .eq('tenant_id', tenantId)
    .eq('approver_user_id', userId)
    .eq('status', 'pending');

  const docIds = (steps ?? []).map((s) => s.document_id as string);
  if (docIds.length === 0) return [];

  // v1.1 M13: pending_post_facto 도 결재함에 포함 (현재 단계 결재자 시야)
  const { data: docs } = await supabase
    .from('approval_documents')
    .select(
      'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id, urgency, content'
    )
    .in('id', docIds)
    .in('status', ['in_progress', 'pending_post_facto'])
    .order('submitted_at', { ascending: false });

  // 내 pending step 의 group_order 들 (병렬이면 한 문서에 동일 값 중복)
  const myGroupsByDoc = new Map<string, Set<number>>();
  for (const s of steps ?? []) {
    const docId = s.document_id as string;
    const g = s.group_order as number;
    if (!myGroupsByDoc.has(docId)) myGroupsByDoc.set(docId, new Set<number>());
    myGroupsByDoc.get(docId)!.add(g);
  }
  return ((docs as unknown as DocRow[]) ?? []).filter((d) =>
    myGroupsByDoc.get(d.id)?.has(d.current_step_index) ?? false
  );
}

/**
 * 내가 approver로 참여하여 **이미 처리한(non-pending)** step 이 있는 문서 ID.
 * in_progress/completed/rejected 탭에서 "참여자 시점"을 열기 위해 사용.
 *
 * pending 을 제외하는 이유:
 *   - 내 차례가 아직 안 온 (앞 그룹 미완료) pending step 만 있는 문서까지 진행 탭에
 *     노출되면 순서가 안 온 결재자에게 미리 보이는 버그 (APP-20260415-0010 사례).
 *   - 내 차례가 오면 "대기" 탭에 표시되고 (loadPendingDocs), 처리 후 approved/rejected/agreed/
 *     skipped 로 전환되면서 참여자 시점에 포함돼 진행/완료/반려 탭에 남는다.
 *
 * drafts 탭은 기안자 전용이라 미포함.
 */
async function fetchMyParticipatedDocIds(
  supabase: SupabaseClient,
  tenantId: string,
  userId: string
): Promise<string[]> {
  const { data } = await supabase
    .from('approval_steps')
    .select('document_id')
    .eq('tenant_id', tenantId)
    .eq('approver_user_id', userId)
    .neq('status', 'pending');
  return Array.from(new Set((data ?? []).map((s) => s.document_id as string)));
}

/**
 * drafter_id 또는 참여 문서 ID 목록으로 or 필터 적용.
 * 참여 문서가 없으면 drafter_id 단일 조건으로 fallback.
 */
function applyMineOrParticipated<T extends { or: Function; eq: Function }>(
  q: T,
  userId: string,
  participatedIds: string[]
): T {
  if (participatedIds.length === 0) {
    return q.eq('drafter_id', userId);
  }
  return q.or(`drafter_id.eq.${userId},id.in.(${participatedIds.join(',')})`);
}

async function loadCountsExcludingPending(
  supabase: SupabaseClient,
  tenantId: string,
  userId: string,
  participatedIds: string[]
): Promise<Omit<InboxCounts, 'pending'>> {
  const inProgressQ = supabase
    .from('approval_documents')
    .select('id', { count: 'exact', head: true })
    .eq('tenant_id', tenantId)
    .in('status', ['in_progress', 'pending_post_facto']);
  const completedQ = supabase
    .from('approval_documents')
    .select('id', { count: 'exact', head: true })
    .eq('tenant_id', tenantId)
    .in('status', ['completed', 'withdrawn']);
  const rejectedQ = supabase
    .from('approval_documents')
    .select('id', { count: 'exact', head: true })
    .eq('tenant_id', tenantId)
    .eq('status', 'rejected');

  const [inProgress, completed, rejected, drafts] = await Promise.all([
    applyMineOrParticipated(inProgressQ, userId, participatedIds),
    applyMineOrParticipated(completedQ, userId, participatedIds),
    applyMineOrParticipated(rejectedQ, userId, participatedIds),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .eq('status', 'draft')
  ]);

  return {
    in_progress: inProgress.count ?? 0,
    completed: completed.count ?? 0,
    rejected: rejected.count ?? 0,
    drafts: drafts.count ?? 0
  };
}

type DocRow = {
  id: string;
  doc_number: string;
  status: string;
  current_step_index: number;
  drafter_id: string;
  submitted_at: string | null;
  completed_at: string | null;
  updated_at: string;
  form_id: string;
  urgency: string;
  content: Record<string, unknown>;
};

type FormLookup = Map<string, { name: string; code: string }>;

async function fetchFormsLookup(
  supabase: SupabaseClient,
  formIds: string[]
): Promise<FormLookup> {
  if (formIds.length === 0) return new Map();
  const { data } = await supabase
    .from('approval_forms')
    .select('id, name, code')
    .in('id', Array.from(new Set(formIds)));
  return new Map(
    (data ?? []).map((f) => [
      f.id as string,
      { name: f.name as string, code: f.code as string }
    ])
  );
}

async function loadDocumentsForTab(
  supabase: SupabaseClient,
  tenantId: string,
  userId: string,
  tab: InboxTab,
  participatedIds: string[]
): Promise<DocRow[]> {
  const DOC_COLS =
    'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id, urgency, content';

  switch (tab) {
    case 'pending': {
      return loadPendingDocs(supabase, tenantId, userId);
    }

    case 'in_progress': {
      // v1.1 M13: pending_post_facto 도 진행 중으로 분류
      // 기안자 OR 결재 참여자 시점 통합
      const base = supabase
        .from('approval_documents')
        .select(DOC_COLS)
        .eq('tenant_id', tenantId)
        .in('status', ['in_progress', 'pending_post_facto']);
      const { data } = await applyMineOrParticipated(base, userId, participatedIds)
        .order('submitted_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'completed': {
      // 기안자 OR 결재 참여자 시점 통합
      const base = supabase
        .from('approval_documents')
        .select(DOC_COLS)
        .eq('tenant_id', tenantId)
        .in('status', ['completed', 'withdrawn']);
      const { data } = await applyMineOrParticipated(base, userId, participatedIds)
        .order('updated_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'rejected': {
      // 기안자 OR 결재 참여자 시점 통합
      const base = supabase
        .from('approval_documents')
        .select(DOC_COLS)
        .eq('tenant_id', tenantId)
        .eq('status', 'rejected');
      const { data } = await applyMineOrParticipated(base, userId, participatedIds)
        .order('updated_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'drafts': {
      const { data } = await supabase
        .from('approval_documents')
        .select(DOC_COLS)
        .eq('tenant_id', tenantId)
        .eq('drafter_id', userId)
        .eq('status', 'draft')
        .order('updated_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }
  }
}

export const load: PageServerLoad = async ({ locals, url, parent }) => {
  const { currentTenant } = await parent();
  const tab = parseTab(url.searchParams.get('tab'));

  const tenantId = currentTenant!.id;
  const userId = locals.user!.id;

  // pending helper는 counts와 list 양쪽에서 쓰이므로 1회만 계산
  const pendingDocs = await loadPendingDocs(locals.supabase, tenantId, userId);

  // "한 번이라도 결재함에 들어왔으면 계속 노출" — 참여 문서 ID는 counts + list 양쪽에서 재사용
  const participatedIds = await fetchMyParticipatedDocIds(locals.supabase, tenantId, userId);

  const [nonPendingCounts, otherTabDocs] = await Promise.all([
    loadCountsExcludingPending(locals.supabase, tenantId, userId, participatedIds),
    tab === 'pending'
      ? Promise.resolve(null)
      : loadDocumentsForTab(locals.supabase, tenantId, userId, tab, participatedIds)
  ]);

  const docs = tab === 'pending' ? pendingDocs : (otherTabDocs ?? []);
  const counts: InboxCounts = {
    pending: pendingDocs.length,
    in_progress: nonPendingCounts.in_progress,
    completed: nonPendingCounts.completed,
    rejected: nonPendingCounts.rejected,
    drafts: nonPendingCounts.drafts
  };

  const formsLookup = await fetchFormsLookup(
    locals.supabase,
    docs.map((d) => d.form_id)
  );
  const drafterMap = await fetchProfilesByIds(
    locals.supabase,
    docs.map((d) => d.drafter_id)
  );

  const rows = docs.map((d) => {
    const form = formsLookup.get(d.form_id);
    const drafter = drafterMap.get(d.drafter_id);
    return {
      id: d.id,
      doc_number: d.doc_number,
      status: d.status,
      form_name: form?.name ?? '(양식 없음)',
      form_code: form?.code ?? 'general',
      title: (d.content?.title as string) ?? (d.content?.subject as string) ?? '',
      drafter_name: drafter?.display_name ?? '(알 수 없음)',
      submitted_at: d.submitted_at,
      completed_at: d.completed_at,
      updated_at: d.updated_at,
      urgency: d.urgency ?? '일반'
    };
  });

  return { tab, counts, rows };
};

// v2.2 M3: 일괄 결재
export const actions = {
  batchApprove: async ({ request, locals, params }: { request: Request; locals: App.Locals; params: Record<string, string> }) => {
    if (!locals.user) return { batchResult: [] };

    const fd = await request.formData();
    const ids = JSON.parse(fd.get('documentIds')?.toString() ?? '[]') as string[];
    const comment = fd.get('comment')?.toString() ?? '';

    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const docId of ids) {
      const { error } = await locals.supabase.rpc('fn_approve_step', {
        p_document_id: docId,
        p_comment: comment || null
      });
      results.push({ id: docId, ok: !error, error: error?.message });
    }
    return { batchResult: results };
  },

  batchReject: async ({ request, locals, params }: { request: Request; locals: App.Locals; params: Record<string, string> }) => {
    if (!locals.user) return { batchResult: [] };

    const fd = await request.formData();
    const ids = JSON.parse(fd.get('documentIds')?.toString() ?? '[]') as string[];
    const comment = fd.get('comment')?.toString() ?? '';

    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const docId of ids) {
      const { error } = await locals.supabase.rpc('fn_reject_step', {
        p_document_id: docId,
        p_comment: comment || '일괄 반려'
      });
      results.push({ id: docId, ok: !error, error: error?.message });
    }
    return { batchResult: results };
  }
};
