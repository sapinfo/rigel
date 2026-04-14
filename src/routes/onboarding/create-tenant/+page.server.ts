import { fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import type { Actions, PageServerLoad } from './$types';

const createTenantSchema = z.object({
  slug: z
    .string()
    .trim()
    .min(3, '3자 이상')
    .max(32, '32자 이하')
    .regex(/^[a-z0-9][a-z0-9-]*[a-z0-9]$/, '소문자·숫자·하이픈만 가능 (양끝은 영숫자)'),
  name: z.string().trim().min(1, '조직명을 입력하세요').max(100)
});

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) redirect(303, '/login');

  const { data: existing } = await locals.supabase
    .from('tenant_members')
    .select('tenant_id')
    .eq('user_id', locals.user.id)
    .limit(1);

  if (existing && existing.length > 0) {
    redirect(303, '/');
  }

  return {};
};

export const actions: Actions = {
  default: async ({ request, locals }) => {
    if (!locals.user) return fail(401);

    const formData = await request.formData();
    const values = {
      slug: formData.get('slug')?.toString() ?? '',
      name: formData.get('name')?.toString() ?? ''
    };

    const parsed = createTenantSchema.safeParse({
      slug: formData.get('slug'),
      name: formData.get('name')
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed), values });
    }

    const { slug, name } = parsed.data;
    const withSample = formData.get('withSample') === 'on';

    const { data: tenant, error } = await locals.supabase
      .rpc('fn_create_tenant', { p_slug: slug, p_name: name })
      .single();

    if (error) {
      const msg =
        error.code === '23505'
          ? '이미 사용 중인 주소입니다'
          : error.message || '조직 생성 실패';
      return fail(400, { errors: formError(msg), values });
    }

    const tenantData = tenant as { id: string; slug: string };

    // 샘플 데이터 생성 요청 시 — 실패해도 조직 생성은 이미 완료된 상태이므로
    // fatal로 처리하지 않고 warning만 콘솔에 남기고 inbox로 진행.
    if (withSample) {
      const { error: seedErr } = await locals.supabase.rpc('fn_seed_sample_data', {
        p_tenant_id: tenantData.id
      });
      if (seedErr) {
        // eslint-disable-next-line no-console
        console.warn('[onboarding] sample data seeding failed:', seedErr.message);
      }
    }

    redirect(303, `/t/${tenantData.slug}/approval/inbox`);
  }
};
