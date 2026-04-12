import type { NotificationType } from './types/approval';

export const NOTIFICATION_TYPE_LABEL: Record<NotificationType, string> = {
	approval_requested: '결재 요청',
	approved: '결재 완료',
	rejected: '반려',
	commented: '코멘트',
	withdrawn: '회수'
};
