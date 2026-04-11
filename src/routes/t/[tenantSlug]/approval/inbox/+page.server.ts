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
  const { data: steps } = await supabase
    .from('approval_steps')
    .select('document_id, step_index')
    .eq('tenant_id', tenantId)
    .eq('approver_user_id', userId)
    .eq('status', 'pending');

  const docIds = (steps ?? []).map((s) => s.document_id as string);
  if (docIds.length === 0) return [];

  const { data: docs } = await supabase
    .from('approval_documents')
    .select(
      'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id'
    )
    .in('id', docIds)
    .eq('status', 'in_progress')
    .order('submitted_at', { ascending: false });

  // 내 step이 실제로 current step과 일치하는 문서만
  const stepByDoc = new Map<string, number>();
  for (const s of steps ?? []) {
    stepByDoc.set(s.document_id as string, s.step_index as number);
  }
  return ((docs as unknown as DocRow[]) ?? []).filter(
    (d) => stepByDoc.get(d.id) === d.current_step_index
  );
}

async function loadCountsExcludingPending(
  supabase: SupabaseClient,
  tenantId: string,
  userId: string
): Promise<Omit<InboxCounts, 'pending'>> {
  const [inProgress, completed, rejected, drafts] = await Promise.all([
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .eq('status', 'in_progress'),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .in('status', ['completed', 'withdrawn']),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .eq('status', 'rejected'),
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
  tab: InboxTab
): Promise<DocRow[]> {
  switch (tab) {
    case 'pending': {
      return loadPendingDocs(supabase, tenantId, userId);
    }

    case 'in_progress': {
      const { data } = await supabase
        .from('approval_documents')
        .select(
          'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id'
        )
        .eq('tenant_id', tenantId)
        .eq('drafter_id', userId)
        .eq('status', 'in_progress')
        .order('submitted_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'completed': {
      const { data } = await supabase
        .from('approval_documents')
        .select(
          'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id'
        )
        .eq('tenant_id', tenantId)
        .eq('drafter_id', userId)
        .in('status', ['completed', 'withdrawn'])
        .order('updated_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'rejected': {
      const { data } = await supabase
        .from('approval_documents')
        .select(
          'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id'
        )
        .eq('tenant_id', tenantId)
        .eq('drafter_id', userId)
        .eq('status', 'rejected')
        .order('updated_at', { ascending: false });
      return (data as unknown as DocRow[]) ?? [];
    }

    case 'drafts': {
      const { data } = await supabase
        .from('approval_documents')
        .select(
          'id, doc_number, status, current_step_index, drafter_id, submitted_at, completed_at, updated_at, form_id'
        )
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

  const [nonPendingCounts, otherTabDocs] = await Promise.all([
    loadCountsExcludingPending(locals.supabase, tenantId, userId),
    tab === 'pending'
      ? Promise.resolve(null)
      : loadDocumentsForTab(locals.supabase, tenantId, userId, tab)
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
      drafter_name: drafter?.display_name ?? '(알 수 없음)',
      submitted_at: d.submitted_at,
      completed_at: d.completed_at,
      updated_at: d.updated_at
    };
  });

  return { tab, counts, rows };
};
