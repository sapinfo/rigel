import { error, fail, redirect } from '@sveltejs/kit';
import { absenceSchema, coerceAbsenceFormData } from '$lib/server/schemas/absence';
import { zodErrors, formError } from '$lib/forms';
import { fetchAbsence } from '$lib/server/queries/absences';
import { fetchProfilesByIds } from '$lib/server/queries/profiles';
import type { Actions, PageServerLoad } from './$types';

async function resolveTenant(
  supabase: any,
  userId: string,
  slug: string
): Promise<{ id: string; role: string } | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  const t = data.tenant as { id: string; slug: string };
  return { id: t.id, role: data.role };
}

function toInputDate(iso: string): string {
  // HTML <input type="date"> 는 YYYY-MM-DD. KST 기준으로 추출해 저장 시
  // 경계 확장과 일관성 유지 (coerceAbsenceFormData 참조).
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date(iso));
}

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { currentTenant } = await parent();
  const absence = await fetchAbsence(locals.supabase, currentTenant.id, params.id);
  if (!absence) error(404, '부재를 찾을 수 없습니다');

  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, job_title')
    .eq('tenant_id', currentTenant.id);

  const profileMap = await fetchProfilesByIds(
    locals.supabase,
    (memberRows ?? []).map((m) => m.user_id as string)
  );

  const members = (memberRows ?? []).map((m) => {
    const p = profileMap.get(m.user_id as string);
    return {
      user_id: m.user_id as string,
      display_name: p?.display_name ?? '(알 수 없음)',
      email: p?.email ?? '',
      job_title: (m.job_title as string | null) ?? null
    };
  });

  const { data: formRows } = await locals.supabase
    .from('approval_forms')
    .select('id, code, name')
    .eq('tenant_id', currentTenant.id)
    .eq('is_published', true)
    .order('name', { ascending: true });

  const forms = (formRows ?? []).map((f) => ({
    id: f.id as string,
    code: f.code as string,
    name: f.name as string
  }));

  return {
    absence,
    members,
    forms,
    initialValues: {
      user_id: absence.user_id,
      delegate_user_id: absence.delegate_user_id,
      absence_type: absence.absence_type,
      scope_form_id: absence.scope_form_id ?? '',
      start_at: toInputDate(absence.start_at),
      end_at: toInputDate(absence.end_at),
      reason: absence.reason ?? ''
    }
  };
};

export const actions: Actions = {
  update: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant || !['owner', 'admin'].includes(tenant.role)) return fail(403);

    const fd = await request.formData();
    const parsed = absenceSchema.safeParse(
      coerceAbsenceFormData(fd, { includeUserId: true })
    );

    const values = {
      user_id: fd.get('user_id')?.toString() ?? '',
      delegate_user_id: fd.get('delegate_user_id')?.toString() ?? '',
      absence_type: fd.get('absence_type')?.toString() ?? 'other',
      scope_form_id: fd.get('scope_form_id')?.toString() ?? '',
      start_at: fd.get('start_at')?.toString() ?? '',
      end_at: fd.get('end_at')?.toString() ?? '',
      reason: fd.get('reason')?.toString() ?? ''
    };

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed), values });
    }

    const { error: err } = await locals.supabase
      .from('user_absences')
      .update({
        user_id: parsed.data.user_id,
        delegate_user_id: parsed.data.delegate_user_id,
        absence_type: parsed.data.absence_type,
        scope_form_id: parsed.data.scope_form_id,
        start_at: parsed.data.start_at.toISOString(),
        end_at: parsed.data.end_at.toISOString(),
        reason: parsed.data.reason,
        updated_at: new Date().toISOString()
      })
      .eq('id', params.id)
      .eq('tenant_id', tenant.id);

    if (err) {
      const msg =
        err.code === '23514'
          ? '입력값이 제약조건을 위반했습니다 (본인/대리인 또는 기간 확인)'
          : err.message || '부재 수정 실패';
      return fail(400, { errors: formError(msg), values });
    }

    redirect(303, `/t/${params.tenantSlug}/admin/absences`);
  }
};
