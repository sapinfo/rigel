# Archive Index — 2026-04

| Feature | Status | Match | Archived | Path |
|---|---|---|---|---|
| 프로덕션-docker-배포 | completed | 94% | 2026-04-14 | [프로덕션-docker-배포/](./프로덕션-docker-배포/) |
| 그룹웨어-v3.1-확장 | completed | 98% | 2026-04-12 | [그룹웨어-v3.1-확장/](./그룹웨어-v3.1-확장/) |
| 결재선-v3.0-polish-final | completed | 95% | 2026-04-13 | [결재선-v3.0-polish-final/](./결재선-v3.0-polish-final/) |
| 결재선-v2.3-polish | completed | 92% | 2026-04-12 | [결재선-v2.3-polish/](./결재선-v2.3-polish/) |
| 결재선-v2.2-실무완성 | completed | 93% | 2026-04-12 | [결재선-v2.2-실무완성/](./결재선-v2.2-실무완성/) |
| 결재선-v2.1-보강 | completed | 93% | 2026-04-12 | [결재선-v2.1-보강/](./결재선-v2.1-보강/) |
| 전자결재-v2.0-builder | completed | 78% | 2026-04-12 | [전자결재-v2.0-builder/](./전자결재-v2.0-builder/) |
| 전자결재-v1.3-realtime-notification | completed | 91% | 2026-04-12 | [전자결재-v1.3-realtime-notification/](./전자결재-v1.3-realtime-notification/) |
| 전자결재-v1.2-parallel-pdf-hash-signature | completed | 90% | 2026-04-11 | [전자결재-v1.2-parallel-pdf-hash-signature/](./전자결재-v1.2-parallel-pdf-hash-signature/) |
| 전자결재-v1.1-korean-exceptions | completed | 94% | 2026-04-11 | [전자결재-v1.1-korean-exceptions/](./전자결재-v1.1-korean-exceptions/) |

## 프로덕션-docker-배포

**Match Rate 94%** · 2026-04-13 ~ 2026-04-14 · 2 commits

v1 통합 install.sh (맥북/우분투 `/opt` 권한 문제로 실패) → **v2 pivot**: Supabase는 공식 가이드에 위임, Rigel 앱만 `install.sh` 자동화. 2-Step 설치 (~8분), 재실행 안전, `_rigel_installed` 마커로 멱등성 보장.

**산출물**:
- [plan.md](./프로덕션-docker-배포/plan.md) — v1→v2 Architecture Revision 포함
- [design.md](./프로덕션-docker-배포/design.md) — install.sh 6단계 흐름 + kong 라우팅
- [analysis.md](./프로덕션-docker-배포/analysis.md) — 17/17 요건 중 16 ✅, G1 패치 완료
- [report.md](./프로덕션-docker-배포/report.md) — 완료 보고서

**핵심 메트릭**: +416/-2309 (rev 2 refactor) · +193 (G1 docs patch) · install.sh 260→170줄 · `supabase-docker/` 14 파일 git 제거 · E2E 6/7 통과 (macOS+Colima)

**교훈**: 자신이 통제 불가능한 환경 변수(호스트 권한·Docker Desktop 파일공유)를 설치 스크립트로 예측하지 말 것. 공식 가이드에 위임이 최선.

**후속 feature 후보**: `boards-ux-fix` (use:enhance reset), `rls-admin-scope-fix` (admin 부서 가시성)

---

## 결재선-v2.1-보강

v2.0 (match 78%) → **v2.1** (match 93%)

결재선 규칙 관리 GUI + OrgChart 트리 + 기안 시 프리뷰 + 시뮬레이터

**산출물**:
- [plan.md](./결재선-v2.1-보강/결재선-v2.1-보강.plan.md)
- [design.md](./결재선-v2.1-보강/결재선-v2.1-보강.design.md)
- [analysis.md](./결재선-v2.1-보강/결재선-v2.1-보강.analysis.md)
- [report.md](./결재선-v2.1-보강/결재선-v2.1-보강.report.md)

**핵심 메트릭**: 3 migrations (0046~0048) · 3 신규 컴포넌트 · 7 마일스톤 · RuleBuilder GUI · OrgTree 재귀 snippet

---

## 전자결재-v1.3-realtime-notification

v1.2.0 (`8b60fb6`) → **v1.3.0** (`3cefc57`)

실시간 알림·이메일·반응형·PWA — "놓치지 않는 결재"

**산출물**:
- [plan.md](./전자결재-v1.3-realtime-notification/전자결재-v1.3-realtime-notification.plan.md) — Plan Plus
- [design.md](./전자결재-v1.3-realtime-notification/전자결재-v1.3-realtime-notification.design.md) — Realtime/Edge Function/PWA 명세
- [analysis.md](./전자결재-v1.3-realtime-notification/전자결재-v1.3-realtime-notification.analysis.md) — Match Rate 91% (79%→91%, 1 iteration)
- [report.md](./전자결재-v1.3-realtime-notification/전자결재-v1.3-realtime-notification.report.md) — 완료 보고서

**핵심 메트릭**: 3 migrations (0038~0040) · NotificationBell/Dropdown · Edge Function · PWA · 반응형 햄버거

---

## 전자결재-v1.2-parallel-pdf-hash-signature

v1.1.0 (`cb703d7`) → **v1.2.0** (`8b60fb6`)

병렬결재·PDF출력·본문해시·서명이미지 — 감사 가능한 한국형 결재 완성

**산출물**:
- [plan.md](./전자결재-v1.2-parallel-pdf-hash-signature/전자결재-v1.2-parallel-pdf-hash-signature.plan.md) — Plan Plus
- [design.md](./전자결재-v1.2-parallel-pdf-hash-signature/전자결재-v1.2-parallel-pdf-hash-signature.design.md) — DB/RPC/PDF/Hash/Signature 명세
- [analysis.md](./전자결재-v1.2-parallel-pdf-hash-signature/전자결재-v1.2-parallel-pdf-hash-signature.analysis.md) — Match Rate 90%, gap 10건 (5 intentional)
- [report.md](./전자결재-v1.2-parallel-pdf-hash-signature/전자결재-v1.2-parallel-pdf-hash-signature.report.md) — 완료 보고서

**핵심 메트릭**: 7 migrations (0031~0037) · 33+ Vitest · smoke S40~S46 · puppeteer PDF · RFC 8785 JCS

---

## 전자결재-v1.1-korean-exceptions

v1.0.0 (`d957381`) → **v1.1.0** (`cb703d7`)

Sequential 4-Slice 한국형 결재 예외 4종 (전결·대결·후결·부재자동)

**산출물**:
- [plan.md](./전자결재-v1.1-korean-exceptions/plan.md) — Plan Plus (intent/alternatives/YAGNI)
- [design.md](./전자결재-v1.1-korean-exceptions/design.md) — DB/RPC/UI 명세
- [analysis.md](./전자결재-v1.1-korean-exceptions/analysis.md) — Match Rate 94%, gap 7건
- [report.md](./전자결재-v1.1-korean-exceptions/report.md) — 완료 보고서

**핵심 메트릭**: 14 migrations (0019~0030) · smoke 13/15 PASS · 0 error/0 warning · 0 security advisor WARN · pg_cron 첫 도입
