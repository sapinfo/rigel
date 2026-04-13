import { fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import type { Actions, PageServerLoad } from './$types';

const signupSchema = z.object({
  email: z.string().email('올바른 이메일 형식이 아닙니다'),
  password: z
    .string()
    .min(8, '비밀번호는 최소 8자 이상이어야 합니다')
    .max(72, '비밀번호가 너무 깁니다'),
  display_name: z.string().trim().min(1, '이름을 입력하세요').max(50)
});

/**
 * Safe-redirect: path만 허용 (외부 URL 리디렉션 공격 방지).
 */
function safeRedirectPath(raw: string | null): string {
  if (raw && raw.startsWith('/') && !raw.startsWith('//')) {
    return raw;
  }
  return '/';
}

export const load: PageServerLoad = async ({ url }) => {
  return {
    redirectTo: safeRedirectPath(url.searchParams.get('redirect')),
    prefilledEmail: url.searchParams.get('email') ?? ''
  };
};

export const actions: Actions = {
  default: async ({ request, locals, url }) => {
    const formData = await request.formData();
    const values = {
      email: formData.get('email')?.toString() ?? '',
      display_name: formData.get('display_name')?.toString() ?? ''
    };

    const parsed = signupSchema.safeParse({
      email: formData.get('email'),
      password: formData.get('password'),
      display_name: formData.get('display_name')
    });

    if (!parsed.success) {
      return fail(400, { errors: zodErrors(parsed), values });
    }

    const { email, password, display_name } = parsed.data;

    const { error } = await locals.supabase.auth.signUp({
      email,
      password,
      options: {
        data: { display_name },
        emailRedirectTo: `${url.origin}/`
      }
    });

    if (error) {
      console.error('[signup] Auth error:', error.message, error.status, error);
      return fail(400, { errors: formError(error.message || 'Authentication service error'), values });
    }

    // 가입 후 ?redirect=<path>로 복귀 (초대 플로우 등에서 사용).
    // path가 없으면 / 로 → entry redirect가 onboarding/create-tenant 로 보냄.
    const redirectTo = safeRedirectPath(url.searchParams.get('redirect'));
    redirect(303, redirectTo);
  }
};
