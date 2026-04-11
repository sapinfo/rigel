import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
  // GET access → just go to /login
  redirect(303, '/login');
};

export const actions: Actions = {
  default: async ({ locals }) => {
    await locals.supabase.auth.signOut();
    redirect(303, '/login');
  }
};
