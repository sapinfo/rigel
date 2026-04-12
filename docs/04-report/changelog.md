# Changelog

---

## [2026-04-12] — v1.3 전자결재 실시간 알림 완료

### Added
- notifications 테이블 + fn_create_notification trigger + RLS (migrations 0038~0040)
- mark_notification_read / mark_all_notifications_read / get_notifications RPC 3개
- NotificationBell.svelte + NotificationDropdown.svelte 신규 컴포넌트
- Supabase Realtime 구독 (+layout.svelte 통합)
- Edge Function send-notification-email (console fallback for dev)
- 반응형 header (hamburger menu + mobile nav panel)
- PWA manifest.json + service-worker.ts + icons (192x192, 512x512)
- Apple PWA meta 태그 (app.html)
- pg_cron 90일 이상 읽음 알림 자동 삭제

### Changed
- +layout.svelte: NotificationBell 추가 + 햄버거 메뉴 통합
- +layout.server.ts: unreadCount SSR 초기값 로드
- app.html: manifest 링크 + theme-color + Apple PWA meta

---
