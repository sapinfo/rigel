# Archive Index — 2026-04

| Feature | Status | Match | Archived | Path |
|---|---|---|---|---|
| 결재선-v2.2-실무완성 | completed | 93% | 2026-04-12 | [결재선-v2.2-실무완성/](./결재선-v2.2-실무완성/) |
| 결재선-v2.1-보강 | completed | 93% | 2026-04-12 | [결재선-v2.1-보강/](./결재선-v2.1-보강/) |
| 전자결재-v2.0-builder | completed | 78% | 2026-04-12 | [전자결재-v2.0-builder/](./전자결재-v2.0-builder/) |
| 전자결재-v1.3-realtime-notification | completed | 91% | 2026-04-12 | [전자결재-v1.3-realtime-notification/](./전자결재-v1.3-realtime-notification/) |
| 전자결재-v1.2-parallel-pdf-hash-signature | completed | 90% | 2026-04-11 | [전자결재-v1.2-parallel-pdf-hash-signature/](./전자결재-v1.2-parallel-pdf-hash-signature/) |
| 전자결재-v1.1-korean-exceptions | completed | 94% | 2026-04-11 | [전자결재-v1.1-korean-exceptions/](./전자결재-v1.1-korean-exceptions/) |

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
