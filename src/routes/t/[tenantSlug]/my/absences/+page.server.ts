import { fail } from '@sveltejs/kit';
import { selfAbsenceSchema, coerceAbsenceFormData } from '$lib/server/schemas/absence';
import { zodErrors, formError } from '$lib/forms';
import { fetchAbsences } from '$lib/server/queries/absences';
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

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { currentTenant } = await parent();
  const userId = locals.user!.id;

  // 본인 부재 목록 (RLS로 본인 것만 반환되지만 명시 필터로 안전)
  const absences = await fetchAbsences(locals.supabase, currentTenant.id, { userId });

  // 대리인 선택용 — 본인 제외 멤버
  const { data: memberRows } = await locals.supabase
    .from('tenant_members')
    .select('user_id, job_title')
    .eq('tenant_id', currentTenant.id)
    .neq('user_id', userId);

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

  // 범위 선택용 발행된 양식
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

  return { absences, members, forms };
};

export const actions: Actions = {
  create: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant) return fail(404);

    const fd = await request.formData();
    const parsed = selfAbsenceSchema.safeParse(
      coerceAbsenceFormData(fd, { includeUserId: false })
    );

    const values = {
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

    const { error: err } = await locals.supabase.from('user_absences').insert({
      tenant_id: tenant.id,
      user_id: locals.user.id,
      delegate_user_id: parsed.data.delegate_user_id,
      absence_type: parsed.data.absence_type,
      scope_form_id: parsed.data.scope_form_id,
      start_at: parsed.data.start_at.toISOString(),
      end_at: parsed.data.end_at.toISOString(),
      reason: parsed.data.reason
    });

    if (err) {
      const msg =
        err.code === '23514'
          ? '입력값이 제약조건을 위반했습니다 (대리인 또는 기간 확인)'
          : err.message || '부재 등록 실패';
      return fail(400, { errors: formError(msg), values });
    }

    return { ok: true };
  },

  deleteAbsence: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const tenant = await resolveTenant(
      locals.supabase,
      locals.user.id,
      params.tenantSlug
    );
    if (!tenant) return fail(404);

    const fd = await request.formData();
    const id = fd.get('id')?.toString();
    if (!id) return fail(400, { error: 'id 누락' });

    const { error: err } = await locals.supabase
      .from('user_absences')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id)
      .eq('user_id', locals.user.id);

    if (err) return fail(400, { error: err.message });
    return { ok: true };
  }
};
