import { error, fail } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { PageServerLoad, Actions } from './$types';

// CLAUDE.md 규칙: Actions에서 locals.currentTenant 사용 금지.
async function resolveTenantId(
  supabase: SupabaseClient,
  userId: string,
  slug: string
): Promise<string | null> {
  const { data } = await supabase
    .from('tenant_members')
    .select('tenant:tenants!inner(id)')
    .eq('user_id', userId)
    .eq('tenant.slug', slug)
    .maybeSingle();
  if (!data) return null;
  return (data.tenant as unknown as { id: string }).id;
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) error(401, 'Not authenticated');
  const { currentTenant } = await parent();

  const { data: profile } = await locals.supabase
    .from('employee_profiles')
    .select('*')
    .eq('user_id', locals.user.id)
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  const { data: baseProfile } = await locals.supabase
    .from('profiles')
    .select('display_name')
    .eq('id', locals.user.id)
    .maybeSingle();

  // 직급은 admin이 `관리 > 조직 관리 > 멤버 배정` 에서 할당 (tenant_members.job_title_id).
  // 내 프로필에서는 읽기 전용 표시만.
  const { data: tm } = await locals.supabase
    .from('tenant_members')
    .select('job_title:job_titles(name, level)')
    .eq('user_id', locals.user.id)
    .eq('tenant_id', currentTenant.id)
    .maybeSingle();

  const assignedJobTitle = tm?.job_title as unknown as { name: string; level: number } | null;

  return {
    profile: profile ?? null,
    fullName: (baseProfile?.display_name as string) ?? '',
    email: locals.user.email ?? '',
    assignedJobTitle: assignedJobTitle
      ? { name: assignedJobTitle.name, level: assignedJobTitle.level }
      : null
  };
};

export const actions: Actions = {
  save: async ({ request, locals, params }) => {
    if (!locals.user) error(401, 'Not authenticated');

    const tenantId = await resolveTenantId(locals.supabase, locals.user.id, params.tenantSlug);
    if (!tenantId) return fail(404, { message: 'Tenant not found' });

    const fd = await request.formData();

    // 이름 수정: profiles.display_name 은 RLS profiles_self_update 로 본인만 가능.
    // trim 후 1~50자 검증. 빈값 저장 금지.
    const displayNameRaw = (fd.get('display_name') as string) ?? '';
    const displayName = displayNameRaw.trim();
    if (displayName.length < 1 || displayName.length > 50) {
      return fail(400, { message: '이름은 1~50자 사이로 입력해주세요.' });
    }

    const { error: nameErr } = await locals.supabase
      .from('profiles')
      .update({ display_name: displayName, updated_at: new Date().toISOString() })
      .eq('id', locals.user.id);
    if (nameErr) return fail(400, { message: nameErr.message });

    const payload = {
      user_id: locals.user.id,
      tenant_id: tenantId,
      employee_number: (fd.get('employee_number') as string) || null,
      hire_date: (fd.get('hire_date') as string) || null,
      phone_office: (fd.get('phone_office') as string) || null,
      phone_mobile: (fd.get('phone_mobile') as string) || null,
      job_title: (fd.get('job_title') as string) || null,
      // job_position은 프로필에서 편집 불가. admin이 tenant_members.job_title_id로 관리.
      // 폼에서 필드 제거했으므로 payload에서도 제외 (기존 값 보존).
      bio: (fd.get('bio') as string) || null,
      updated_at: new Date().toISOString()
    };

    const { error: err } = await locals.supabase
      .from('employee_profiles')
      .upsert(payload, { onConflict: 'user_id' });

    if (err) return fail(400, { message: err.message });
    return { success: true };
  }
};
