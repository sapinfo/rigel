import { error } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

/**
 * Admin 전용 레이아웃 — owner/admin role만 접근 가능.
 * 상위 /t/[tenantSlug]/+layout.server.ts에서 currentTenant가 세팅됨.
 */
export const load: LayoutServerLoad = async ({ parent }) => {
  const { currentTenant } = await parent();
  if (!currentTenant || !['owner', 'admin'].includes(currentTenant.role)) {
    error(403, '관리자 권한이 필요합니다');
  }
  return { currentTenant };
};
