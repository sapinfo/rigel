import type { LayoutServerLoad } from './$types';

/**
 * M1: Session hydration only.
 * M3 will add tenant list loading for TenantSwitcher.
 */
export const load: LayoutServerLoad = async ({ locals }) => {
  return {
    session: locals.session,
    user: locals.user,
    currentTenant: null
  };
};
