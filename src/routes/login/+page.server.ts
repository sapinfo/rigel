import { fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { zodErrors, formError } from '$lib/forms';
import type { Actions, PageServerLoad } from './$types';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const load: PageServerLoad = async ({ url }) => {
  return {
    redirectTo: url.searchParams.get('redirect') ?? '/'
  };
};

export const actions: Actions = {
  default: async ({ request, locals, url }) => {
    const formData = await request.formData();
    const values = { email: formData.get('email')?.toString() ?? '' };

    const parsed = loginSchema.safeParse({
      email: formData.get('email'),
      password: formData.get('password')
    });

    if (!parsed.success) {
      return fail(400, {
        errors: formError('이메일과 비밀번호를 입력하세요'),
        values
      });
    }

    const { email, password } = parsed.data;

    const { error } = await locals.supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      return fail(400, {
        errors: formError('이메일 또는 비밀번호가 올바르지 않습니다'),
        values
      });
    }

    const redirectTo = url.searchParams.get('redirect') ?? '/';
    const safeRedirect = redirectTo.startsWith('/') ? redirectTo : '/';
    redirect(303, safeRedirect);
  }
};
