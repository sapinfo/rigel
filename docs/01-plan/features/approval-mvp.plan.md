# Plan — 전자결재 MVP (approval-mvp)

> Feature: `approval-mvp`
> Method: Plan Plus (Brainstorming-Enhanced PDCA Planning)
> Stack: SvelteKit 2 + Svelte 5 (runes) + @supabase/ssr + Supabase local
> Author: Rigel team
> Date: 2026-04-11
> Phase: PDCA Plan

---

## Executive Summary

| 항목 | 내용 |
|---|---|
| **Feature** | 한국형 전자결재 MVP (multi-tenant SaaS) |
| **타겟** | 국내 SMB 중소기업 (10~300명 조직) |
| **1차 마일스톤** | v1.0 "Shippable Core" |
| **스택** | SvelteKit 2 · Svelte 5 runes · @supabase/ssr · Supabase(Postgres+Auth+Storage) |
| **테넌시** | Multi-tenant · 공유 스키마 + `tenant_id` + RLS · 경로 기반 `/t/[slug]/` |
| **핵심 차별점** | JSON 스키마 기반 동적 양식 (드래그앤드롭 빌더 없이도 고객사별 양식 추가 가능) |
| **MVP 성공 기준** | 도입 고객사 수 + 주 3회 이상 접속 Retention |

### Value Delivered (4관점)

| 관점 | 내용 |
|---|---|
| **Problem** | SMB가 종이·엑셀·메신저로 흩어진 결재를 디지털화하려 할 때, 두레이·다우오피스는 기능이 많지만 관성·가격 부담이 있고, 자체 개발은 한국형 결재 예외규칙(전결/대결/후결/부재/병렬) 구현이 버거움 |
| **Solution** | Phased v1 전략으로 "v1.0에서 빠르게 돌아가는 순차 결재 + JSON 스키마 양식"을 먼저 출시하고, v1.1~v1.3에서 한국형 예외·법적효력·UX를 점진 추가. 멀티 테넌트로 SaaS 과금/운영 비용 최소화 |
| **Function UX Effect** | 회원가입 → 조직 생성 → 양식 5종 자동 시드 → 기안 → 순차 결재 → 완료까지 90초 내 첫 경험. 결재함 badge, use:enhance로 JS-off 환경에서도 결재 처리 |
| **Core Value** | "한국형 결재가 가능한 SMB용 가벼운 SaaS" + "우리 양식을 JSON만 편집하면 바로 추가" = 경쟁사와 차별화 지점 |

---

## 0. Phased v1 Roadmap

Plan 문서는 **v1.0 상세설계**에 집중하고, 나머지 마일스톤은 "Planned Next"로 요약합니다.

| | v1.0 Shippable Core | v1.1 Korean Exceptions | v1.2 Parallel & Legal | v1.3 Polish |
|---|---|---|---|---|
| 결재 흐름 | 기안→순차 승인/반려, 수동 결재선, 결재함(5탭), 참조/공람, 코멘트 | — | + 병렬결재/병렬합의, 합의 단계(검토/협조) | — |
| 예외규칙 | — | 전결·대결·후결·부재자동 전환 (pg_cron) | — | — |
| 양식 | JSON 스키마 렌더러 + 기본 5종 | — | — | — |
| 법적 효력 | 감사 로그 (append-only) | — | PDF 변환·해시(SHA256)·전자서명 이미지 | — |
| 알림 | 페이지 진입 시 badge 폴링 | — | — | Realtime 팝업 + 이메일 |
| Storage | 첨부파일 1 버킷 | — | + `approval-archives` (완료 PDF) | — |
| 모바일 | 기본 반응형 | — | — | 모바일 UX 최적화 |
| 외부 판매 | ⚠️ 제한적 | ✅ SMB | ✅ SMB | ✅ SMB |

---

## 1. User Intent Discovery

### 1.1 핵심 문제 (Q1)

> "디지털 결재 흐름 자체 + 양식/자동결재선 차별화 + 한국형 예외규칙 완벽 재현 + 법적 효력·감사 추적"

— 4개 축 **모두**가 핵심 문제로 식별됨. MVP 전략은 Phased v1으로 쪼개서 4축을 순차적으로 커버.

### 1.2 타겟 사용자 (Q2)

**국내 SMB 중소기업 전 구성원 (10~300명)**

- 경쟁군: 두레이·다우오피스·카카오워크·플로우
- CSAP 부담 없는 민간 시장
- 일반 직원 + IT 담당 관리자 1명이 주된 이해관계자

### 1.3 성공 기준 (Q3)

**도입 고객사 수 + Retention (주 3회 이상 접속)**

- 단순 기능 커버리지가 아닌 **실제 사용률**로 검증
- "회사 전체가 실제 결재를 여기서 한다" 수준의 도입
- 이 기준이 Phase 3.5의 Phased v1 전략과 Multi-tenant 아키텍처 결정의 직접적 동인

### 1.4 제약 조건 (자동 도출)

| 제약 | 영향 |
|---|---|
| 조사 문서 난이도 표(11.1) 상 "빌더·자동결재선 규칙 엔진 = 난이도 상" | v1.0에서 제외, v2로 이월 |
| Retention = 실사용 마찰 낮아야 함 | 90초 onboarding, use:enhance progressive enhancement |
| 멀티 테넌트 필수 (고객사당 별도 배포 비용 불가) | 공유 스키마 + tenant_id + RLS |
| 전자문서법·전자서명법 준수 (v1.2에서 완성) | v1.0부터 감사 로그 필수 |

---

## 2. Alternatives Explored

### 2.1 양식(Form) 표현 방식 대안

| | A: 고정 양식 3종 | **B: JSON 스키마 동적 양식 ⭐** | C: 드래그&드롭 빌더 |
|---|---|---|---|
| 구성 | 하드코딩 Svelte 컴포넌트 3개 | JSONB 스키마 + 런타임 렌더러 + 기본 5종 + JSON 에디터 | 완전한 로우코드 빌더 + 수식 + 조건부 표시 |
| Pros | 최속 출시, 완전 제어 | Retention 확보, YAGNI 균형, v2에서 빌더 얹을 수 있음 | 경쟁사 동등 |
| Cons | 차별점 0, Retention 불가 | 관리자 UX가 JSON (IT 담당자 1명이면 감내) | MVP 범위 초과, 결재 코어보다 먼저 완성할 가치 없음 |
| Best for | Dogfooding만 | **Rigel 현 상황** | v2+ |

**선택: B**. 근거는 Q3의 Retention 기준 = 양식 커스터마이즈 포기 불가 + YAGNI 원칙 = 드래그&드롭 빌더는 결재 코어 이후.

### 2.2 멀티 테넌시 전략 대안

| | A: 단일 테넌트 배포 | **B: 공유 스키마 + 경로 ⭐** | B': 서브도메인 | C: 스키마당 테넌트 |
|---|---|---|---|---|
| 구성 | 고객사당 Supabase 프로젝트 | `tenant_id` 컬럼 + RLS + `/t/[slug]/` | `{slug}.rigel.app` wildcard DNS | Postgres schema per tenant |
| 구현 난이도 | 낮음 | 중간 | 중간+ | 높음 |
| 운영 비용 | **매우 높음** | 낮음 | 낮음 | 중간 |
| 로컬 개발 | 쉬움 | 쉬움 | 복잡 (DNS) | 복잡 (migration) |
| Rigel 적합도 | ❌ | ✅ SMB SaaS 표준 | 나중 전환 가능 | 과잉 |

**선택: B**. 경로 기반은 로컬 개발 단순하고, 나중에 B'(서브도메인)로 전환 가능(DNS만 바뀜).

### 2.3 결재선 표현 방식

- **채택: 스냅샷 방식** — 상신 시점에 `approval_steps`에 INSERT. 이후 인사발령·양식 수정의 영향에서 진행 중 문서 격리.
- 양식 스키마까지 스냅샷: `approval_documents.form_schema_snapshot` JSONB.

### 2.4 결재 처리 트랜잭션

- **채택: DB 함수(plpgsql) + `SECURITY DEFINER`** — `fn_approve_step`, `fn_reject_step`, `fn_submit_draft`. Form Action은 얇은 래퍼.
- `SELECT ... FOR UPDATE`로 동시성 방어.
- 감사 로그를 함수 내부에서 자동 삽입 → 호출자 실수 방지.

---

## 3. YAGNI Review

### 3.1 포함 항목 (v1.0)

- **결재 워크플로우**: 기안 / 순차 승인·반려 / 결재함(대기·진행·완료·반려·임시) / 참조자·공람자 / 코멘트
- **양식**: JSON 스키마 동적 렌더러 / 기본 5종 시드 / 관리자 JSON 에디터
- **조직도**: flat CRUD + parent_id 재귀 / 사용자 부서 매핑
- **권한/인증**: email+password 로그인 / RLS 2중 방어선 / `safeGetSession()`
- **첨부파일**: presigned URL 직접 업로드 / `{tenant_id}/{doc_id}/` prefix
- **감사 로그**: append-only / DB 함수 내부 자동 기록
- **멀티 테넌트**: `tenants` / `tenant_members` / `tenant_invitations` / 경로 기반 slug
- **회원가입·온보딩**: 가입 → 조직 생성 → 시스템 양식 5종 복사 → inbox
- **초대 플로우**: 토큰 링크 (이메일 미전송)

### 3.2 이월 항목 (v1.1+)

| 항목 | 마일스톤 | 이유 |
|---|---|---|
| 전결·대결·후결·부재자동 전환 | v1.1 | 같은 layer의 기능, 한 번에 설계 유리 |
| 병렬결재·병렬합의·합의 단계 | v1.2 | 동시성·트랜잭션 강화 필요 |
| PDF 변환·SHA256 해시·전자서명 이미지 | v1.2 | Edge Function·archives 버킷·폰트 이슈 |
| Realtime 알림 / 이메일 알림 | v1.3 | v1.0은 페이지 refresh + badge 폴링으로 충분 |
| 모바일 UX 최적화 | v1.3 | v1.0은 Svelte+Tailwind 기본 반응형 |
| 드래그&드롭 양식 빌더 | v2.0 | 결재 코어보다 먼저 완성할 가치 없음 |
| 자동결재선 규칙 엔진 | v2.0 | 양식 빌더와 함께 설계 |
| 전문검색·문서 번호 커스터마이즈 | v2.0 | — |

### 3.3 원칙 적용

- "3줄로 끝나는 건 추상화하지 않는다" → FormRenderer는 단일 컴포넌트, 팩토리 패턴 금지
- "있을지도 모르는 미래 요구사항 설계 금지" → v1.0 테이블은 v1.1 예외규칙 고려해서 미리 컬럼 추가하지 않음. v1.1에서 migration으로 추가
- "내부 코드·프레임워크는 신뢰" → Supabase Auth 세션 검증, SvelteKit use:enhance 기본 동작 신뢰
- "시스템 경계에서만 검증" → Zod로 Form Action 입력 검증 / RLS는 모든 mutation에 적용

---

## 4. Brainstorming Log

### Phase 0: Context Exploration
- 프로젝트 루트 `/Users/inseokko/Downloads/Rigel/` (git 미초기화)
- 기존 코드 없음, package.json·svelte.config.js 없음 (first scaffolding)
- `docs/01-research/korean-groupware-approval-review.md` (SvelteKit 전환 완료, 526줄)
- `.bkit/state/pdca-status.json` 진행 feature 없음, Level=Dynamic
- Supabase local public 스키마 빈 상태

### Phase 1: Intent Discovery
- Q1 핵심 문제: "위의 전부" (4축 모두) → Phased v1 전략 필요
- Q2 타겟: 국내 SMB 전 구성원 (두레이·다우오피스 직접 경쟁)
- Q3 성공 기준: 도입 고객사 수 + Retention → 멀티 테넌트 필수 시사

### Phase 2: Alternatives Exploration
- Approach A (고정 양식 3종) / **B (JSON 스키마) ⭐** / C (드래그&드롭 빌더) 비교
- B 선택: Retention 요구 + YAGNI 균형점

### Phase 3: YAGNI Review
- 4그룹 × 4옵션 = 16개 후보 제시
- 사용자 선택: **16/16 전부 v1 포함** (0개 이월)
- → Phase 3.5 스코프 위험 경고 + Phased v1 마일스톤 제안

### Phase 3.5: Phased v1
- 대안 3개 (Phased / Big-bang / Tighter) 제시
- **Phased v1 선택**: v1.0 상세설계 + v1.1~1.3 "Planned Next" 요약

### Phase 4-1: Architecture
- 스택 확정: SvelteKit 2 + Svelte 5 + @supabase/ssr + Supabase
- v1.0 제외: Realtime·Edge Functions·pg_cron
- 승인 (OK)

### Phase 4-2: Components & Data Model
- 초기 설계 단일 테넌트 → **사용자 지적**: "이거 멀티 테넌트 맞냐?"
- → **멀티 테넌트 리팩터링 (대안 B 선택)**: 공유 스키마 + `tenant_id` + `/t/[slug]/` 경로
- 3개 테이블 추가 (`tenants`, `tenant_members`, `tenant_invitations`)
- 회원가입·온보딩·초대 플로우 신규 추가

### Phase 4-3: Data Flow
- 4개 플로우 시퀀스 검증: 로그인+테넌트진입 / 기안상신 / 결재처리 / 가입+테넌트생성
- 3중 방어선 확인: Action `locals` → RLS `tenant_members` JOIN → RPC 내부 `auth.uid()` 재확인
- 동시성: `SELECT ... FOR UPDATE`
- 엣지 케이스 5건 명시

---

## 5. Scope (v1.0)

### 5.1 In Scope

| 영역 | 기능 |
|---|---|
| 인증 | 이메일+비밀번호 회원가입·로그인, `safeGetSession()`, 쿠키 기반 SSR |
| 테넌시 | 조직 생성, 멤버 초대 (토큰 링크), 역할 (owner/admin/member), 한 사용자 N 테넌트, 스위처 |
| 조직도 | 부서 flat CRUD, 사용자-부서 매핑, 직함 (테넌트별) |
| 양식 | JSON 스키마 정의, 런타임 FormRenderer, 관리자 JSON 에디터, 시스템 양식 5종 시드+복사 |
| 결재 | 수동 결재선 구성, 순차 결재, 승인/반려/회수/임시저장/코멘트, 참조자·공람자 |
| 결재함 | 5탭: 대기 / 진행 / 완료 / 반려 / 임시저장 — 배지 count |
| 첨부파일 | presigned URL 직접 업로드, `{tenant_id}/{doc_id}/` prefix |
| 감사 로그 | 모든 mutation append-only, DB 함수 자동 기록, 문서 상세 타임라인 표시 |
| 권한 | RLS (tenant_members JOIN) + Form Action locals 확인 + RPC 내부 재확인 (3중) |

### 5.2 Out of Scope (v1.1+)

- 전결·대결·후결·부재자동 · 병렬결재·합의단계
- PDF 변환·해시·전자서명
- Realtime·이메일 알림
- 모바일 UX 최적화
- 드래그&드롭 빌더·자동결재선 규칙 엔진
- 전문검색·외부 연동(ERP·회계·근태)
- CSAP 대응·공공 시장

### 5.3 Non-goals

- Windows/Office 플러그인 · Active-X 호환
- 공공(온나라) 포맷 호환
- 결재 문서 타인 대리 작성 (v1.0에서는 기안자 = 작성자)
- 다국어 UI (한국어만)

---

## 6. Architecture

### 6.1 스택

```
┌─────────────────────────────────────────────────────┐
│  Browser (Svelte 5 runes)                           │
│  - $state / $derived / $props / $effect             │
│  - use:enhance (Form Actions, JS-off 지원)          │
└─────────────┬───────────────────────────────────────┘
              │ SSR + fetch (cookies)
┌─────────────▼───────────────────────────────────────┐
│  SvelteKit 2 Server (Node)                          │
│  - hooks.server.ts (Supabase 주입 + safeGetSession) │
│  - t/[tenantSlug]/+layout.server.ts (테넌트 해석)   │
│  - +page.server.ts (load / actions)                 │
│  - lib/server/ (queries / rpcs / schemas)           │
└─────────────┬───────────────────────────────────────┘
              │ @supabase/ssr (createServerClient)
┌─────────────▼───────────────────────────────────────┐
│  Supabase Local (127.0.0.1:54321)                   │
│  - Postgres: 12 migrations (RLS + plpgsql RPCs)     │
│  - Auth: email+password                             │
│  - Storage: approval-attachments (1 bucket)         │
│  ※ Realtime·Edge Functions·pg_cron = v1.1+         │
└─────────────────────────────────────────────────────┘
```

### 6.2 2중 방어선 원칙

| 층 | 역할 | 구현 |
|---|---|---|
| 1 (DB) | 사용자 우회 원천 차단 | RLS 정책: 모든 테이블 `tenant_id IN (SELECT tenant_id FROM tenant_members WHERE user_id = auth.uid())` |
| 2 (Server) | 비즈니스 규칙 검증 | Form Actions에서 `locals.currentTenant.role` 확인 → `supabase.rpc('fn_*')` 호출 |
| 3 (DB 함수) | 원자성 + 최종 검증 | plpgsql `SECURITY DEFINER` 함수 내부에서 step 소유권·상태 재확인 + 감사 로그 자동 기록 |

---

## 7. Components

### 7.1 Frontend 트리

```
src/
├── app.d.ts                              # App.Locals { supabase, session, user, currentTenant?, safeGetSession }
├── hooks.server.ts                       # Supabase 클라이언트 + safeGetSession
├── lib/
│   ├── components/
│   │   ├── FormRenderer.svelte           # JSON 스키마 → 동적 폼 (text/number/date/select/textarea/attachment)
│   │   ├── FormField.svelte              # 단일 필드 + 검증 상태
│   │   ├── ApprovalLine.svelte           # 결재선 편집(기안) / 표시(상세)
│   │   ├── ApproverPicker.svelte         # 조직도 모달
│   │   ├── DocumentHeader.svelte         # 문서번호·기안자·일자·상태
│   │   ├── AttachmentList.svelte         # 업로드/다운로드
│   │   ├── AuditTimeline.svelte          # 감사 로그 타임라인
│   │   ├── InboxTabs.svelte              # 5개 탭 + 배지
│   │   └── TenantSwitcher.svelte         # 한 사용자 N 테넌트
│   ├── server/
│   │   ├── supabase.ts                   # createServerClient 팩토리
│   │   ├── auth.ts                       # safeGetSession 헬퍼
│   │   ├── queries/
│   │   │   ├── documents.ts
│   │   │   ├── forms.ts
│   │   │   ├── org.ts
│   │   │   └── tenants.ts
│   │   ├── rpcs/
│   │   │   ├── submitDraft.ts
│   │   │   ├── approveStep.ts
│   │   │   ├── rejectStep.ts
│   │   │   ├── withdrawDocument.ts
│   │   │   ├── createTenant.ts
│   │   │   └── acceptInvitation.ts
│   │   └── schemas/
│   │       ├── formSchema.ts             # Zod: JSON 스키마 검증
│   │       └── submitSchema.ts           # Zod: 기안 상신 입력
│   └── types/
│       └── approval.ts                   # 공용 TS 타입
└── routes/
    ├── +layout.server.ts                 # session 하이드레이션
    ├── +layout.svelte                    # 공통 셸
    ├── login/              (+page.svelte, +page.server.ts)
    ├── signup/             (+page.svelte, +page.server.ts)
    ├── onboarding/
    │   └── create-tenant/  (+page.svelte, +page.server.ts)
    ├── invite/[token]/     (+page.svelte, +page.server.ts)
    └── t/[tenantSlug]/
        ├── +layout.server.ts             # ★ 테넌트 해석 + 멤버십 검증
        ├── +layout.svelte
        ├── approval/
        │   ├── inbox/              (load: 5탭 쿼리)
        │   ├── drafts/new/[formId]/ (load: 양식+조직도, actions: { saveDraft, submit })
        │   └── documents/[id]/      (load: doc+steps+attachments+audit, actions: { approve, reject, withdraw, comment })
        └── admin/            (+layout.server.ts: role in ('owner','admin'))
            ├── forms/
            │   ├── (+page: 목록)
            │   └── [id]/     (actions: { saveSchema, publish })
            ├── org/          (부서·사용자 CRUD)
            └── members/      (초대 생성·취소·수락 관리)
```

### 7.2 컴포넌트 설계 원칙

- **Svelte 5 runes 기본**: `$state`, `$derived`, `$props`, `$effect`만 사용 (store 최소화)
- **서버 상태는 `form` prop**: `use:enhance`로 Form Action 결과 수신
- **클라이언트 상태는 local `$state`**: tab index, dirty flag 등
- **FormRenderer는 단일 컴포넌트**: 필드 타입별 분기 없이 `FormField` 하나로 표현 (필드 내부에서 type switch)

---

## 8. Data Model

### 8.1 Migration 목록

| # | 파일 | 내용 |
|---|---|---|
| 0001 | `001_profiles.sql` | `profiles` (auth.users 확장, `default_tenant_id` nullable) |
| 0002 | `002_tenants.sql` | `tenants` (slug unique, plan, owner_id, settings JSONB) |
| 0003 | `003_tenant_members.sql` | `tenant_members` ((tenant_id, user_id) PK, role enum, job_title) |
| 0004 | `004_tenant_invitations.sql` | `tenant_invitations` (token unique, email, expires_at, accepted_at) |
| 0005 | `005_departments.sql` | `departments` (tenant_id, parent_id, name, path) + `user_departments` |
| 0006 | `006_approval_forms.sql` | `approval_forms` (tenant_id nullable, schema JSONB, default_approval_line JSONB, version, is_published) |
| 0007 | `007_approval_documents.sql` | `approval_documents` (tenant_id, doc_number, form_schema_snapshot JSONB, content JSONB, status, current_step_index, drafter_id, submitted_at) |
| 0008 | `008_approval_steps.sql` | `approval_steps` (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, comment) |
| 0009 | `009_approval_attachments.sql` | `approval_attachments` (tenant_id, document_id nullable, storage_path, file_name, mime, size, uploaded_by) |
| 0010 | `010_approval_audit_logs.sql` | `approval_audit_logs` (tenant_id, document_id, actor_id, action, payload JSONB, created_at) |
| 0011 | `011_rls_policies.sql` | 모든 테이블 RLS 정책 (SELECT/INSERT/UPDATE/DELETE) |
| 0012 | `012_functions.sql` | plpgsql SECURITY DEFINER: `fn_create_tenant`, `fn_copy_system_forms`, `fn_accept_invitation`, `fn_submit_draft`, `fn_approve_step`, `fn_reject_step`, `fn_withdraw_document` |
| 0013 | `013_seed_system_forms.sql` | 시스템 양식 5종 (`tenant_id IS NULL`): 기안서·휴가신청서·지출결의서·품의서·업무협조전 |

### 8.2 핵심 테이블 개요

```sql
-- tenants
CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]*[a-z0-9]$'),
  name text NOT NULL,
  plan text NOT NULL DEFAULT 'free',
  owner_id uuid NOT NULL REFERENCES auth.users(id),
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- tenant_members
CREATE TABLE tenant_members (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  job_title text,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

-- approval_documents
CREATE TABLE approval_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  doc_number text NOT NULL,
  form_id uuid NOT NULL REFERENCES approval_forms(id),
  form_schema_snapshot jsonb NOT NULL,
  content jsonb NOT NULL,
  drafter_id uuid NOT NULL REFERENCES auth.users(id),
  status text NOT NULL CHECK (status IN ('draft','in_progress','completed','rejected','withdrawn')),
  current_step_index int NOT NULL DEFAULT 0,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, doc_number)
);

-- 대표 RLS 정책 (approval_documents)
CREATE POLICY doc_select ON approval_documents
  FOR SELECT TO authenticated
  USING (
    tenant_id IN (
      SELECT tenant_id FROM tenant_members WHERE user_id = auth.uid()
    )
  );

-- approval_steps의 쓰기 정책 예시
-- (현재 단계 approver만 자기 단계 UPDATE 가능)
CREATE POLICY step_update ON approval_steps
  FOR UPDATE TO authenticated
  USING (
    approver_user_id = auth.uid()
    AND status = 'pending'
    AND tenant_id IN (
      SELECT tenant_id FROM tenant_members WHERE user_id = auth.uid()
    )
  );
```

> 실제 UPDATE는 RPC `fn_approve_step` 경유이므로 이 정책은 백업 방어선.

### 8.3 System Forms Seed

```
tenant_id IS NULL, is_published = true 로 시스템 양식 5종 상주:
1. 일반 기안서 (general)
2. 휴가신청서 (leave-request)
3. 지출결의서 (expense-report)
4. 품의서 (proposal)
5. 업무협조전 (cooperation)

fn_create_tenant 호출 시 fn_copy_system_forms(new_tenant_id)가
tenant_id IS NULL 양식들을 new_tenant_id로 복사 (편집 가능 상태).
```

---

## 9. Data Flow (v1.0)

### 9.1 Login + Tenant Resolution

```
GET /t/acme/approval/inbox
 → hooks.server.ts:
    - createServerClient (cookies getAll/setAll)
    - safeGetSession(): getSession() → getUser() 왕복 검증
    - locals.user = verified user
 → /t/[tenantSlug]/+layout.server.ts.load:
    - SELECT tm.*, t.* FROM tenant_members tm
      JOIN tenants t ON tm.tenant_id = t.id
      WHERE t.slug = $1 AND tm.user_id = auth.uid()
    - 404 if no tenant, 403 if not member
    - locals.currentTenant = { id, slug, role, name }
 → /t/.../approval/inbox/+page.server.ts.load:
    - SELECT documents WHERE tenant_id = locals.currentTenant.id
    - RLS 백업: tenant_members JOIN 재검증
 → Svelte 5 페이지 hydration
```

### 9.2 Draft Submission

```
POST /t/acme/approval/drafts/new/leave-request (action: submit)
 → load 단계에서 이미 form.schema + org tree fetch 완료
 → 기안자 입력: 제목, 기간, 사유, 결재선(수동 편집), 첨부파일
 → 첨부는 presigned URL로 클라이언트 직접 업로드:
    path = "{tenant_id}/pending-{uuid}/{filename}"
 → action: submit
    1. locals.user + locals.currentTenant.role='member'+ 확인
    2. Zod 검증 (form_schema_snapshot 기준)
    3. supabase.rpc('fn_submit_draft', {
         p_tenant_id, p_form_id, p_content,
         p_approval_line, p_attachment_ids
       })
 → fn_submit_draft (plpgsql, SECURITY DEFINER):
    a. tenant_members 멤버십 재확인
    b. 문서번호 발급: APP-20260411-0001
    c. INSERT approval_documents (status='in_progress', form_schema_snapshot=form.schema)
    d. INSERT approval_steps (결재선 스냅샷, 첫 단계 pending)
    e. UPDATE approval_attachments SET document_id=..., storage_path 옮김 (pending→확정)
    f. INSERT approval_audit_logs (action='submit')
    g. RETURN document_id
 → redirect(303, /t/{slug}/approval/documents/{doc_id})
```

### 9.3 Approval Processing

```
POST /t/acme/approval/documents/{id} (action: approve)
 → load: doc + steps + attachments + audit (RLS 자동 필터)
 → canApprove = (steps[current_step_index].approver_user_id === me)
 → UI: ApprovalPanel (승인/반려/회수 + 코멘트)
 → action: approve
    1. Zod 검증 (comment 선택사항)
    2. supabase.rpc('fn_approve_step', { p_document_id, p_comment })
 → fn_approve_step (plpgsql):
    a. SELECT step FOR UPDATE (lock)
    b. 검증:
       - document.status = 'in_progress'
       - steps[current].approver_user_id = auth.uid()
       - steps[current].status = 'pending'
       - tenant_members 재확인
    c. UPDATE step: status='approved', acted_at=now(), comment
    d. IF last approval step:
         UPDATE document SET status='completed'
       ELSE:
         UPDATE document SET current_step_index = current + 1
    e. INSERT audit log (action='approve')
    f. RETURN new state
 → use:enhance → invalidateAll() → 페이지 re-hydrate
```

**반려 플로우**: `fn_reject_step` — 현재 단계에서 `status='rejected'` + document `status='rejected'`, 이후 단계 자동 `status='skipped'`.
**회수 플로우**: `fn_withdraw_document` — drafter만, 어느 단계든 상태 `pending`이면 `status='withdrawn'`.

### 9.4 Signup + Tenant Creation

```
POST /signup (action: default)
 → supabase.auth.signUp → email confirmation off for MVP
 → INSERT profiles (id=new user id, default_tenant_id=NULL)
 → redirect /onboarding/create-tenant

POST /onboarding/create-tenant (action: create)
 → supabase.rpc('fn_create_tenant', { p_slug, p_name })
 → fn_create_tenant:
    1. slug unique 체크 (fail → raise)
    2. INSERT tenants (owner_id = auth.uid)
    3. INSERT tenant_members (role='owner')
    4. fn_copy_system_forms(tenant_id) - 5종 양식 복사
    5. UPDATE profiles SET default_tenant_id
    6. RETURN slug
 → redirect /t/{slug}/approval/inbox
```

### 9.5 Invitation

```
POST /t/acme/admin/members (action: invite)
 → admin role 확인
 → INSERT tenant_invitations (token=gen_random_uuid, expires_at=now+7d)
 → 응답: /invite/{token} 링크 (v1.3 email 발송)

GET /invite/{token}
 → load: 유효성 검증 (expired? accepted?)
 → if !locals.user: /signup?redirect=/invite/{token} 유도
 → if locals.user:
POST /invite/{token} (action: accept)
 → supabase.rpc('fn_accept_invitation', { p_token })
 → fn_accept_invitation:
    1. SELECT invitation WHERE token AND not expired AND not accepted
    2. email 일치 확인 (auth.email() = invitation.email)
    3. INSERT tenant_members
    4. UPDATE invitation SET accepted_at
    5. RETURN tenant slug
 → redirect /t/{slug}/approval/inbox
```

---

## 10. Edge Cases (v1.0)

| 케이스 | 처리 |
|---|---|
| 기안자가 결재선에 자신 포함 | 허용 (관리자 자기 결재 케이스). 단, 결재자 **중복**은 Zod에서 차단 |
| 결재자가 퇴사 (tenant_members 삭제) | v1.0에서는 차단: `ON DELETE RESTRICT` on `approval_steps.approver_user_id`. v1.1의 대결 기능에서 대체자 지정 도입 |
| 임시저장 후 양식 관리자 수정 | 임시저장(draft)은 스키마 스냅샷 없음. 상신 시점에 현재 published 스키마를 스냅샷. 이미 상신된 문서는 영향 없음 |
| 첨부 업로드 중 브라우저 종료 | `pending-{uuid}` prefix → v1.1 pg_cron cleanup. v1.0은 방치 |
| 동일 slug 생성 시도 | DB unique → `fail(409, { field: 'slug', message: '이미 사용 중' })` |
| 한 사용자 복수 테넌트 | `TenantSwitcher.svelte`로 전환 + `profiles.default_tenant_id` 업데이트 |
| Form Action 직접 호출 (csrf) | SvelteKit 기본 CSRF 보호 활성화 (`csrf.checkOrigin = true`) |
| 세션 만료 중 action 호출 | `use:enhance` 인터셉트 → 302 redirect 감지 → `/login` |

---

## 11. Risks

| # | 리스크 | 완화책 |
|---|---|---|
| 1 | 멀티 테넌트 RLS 실수로 크로스 테넌트 누출 | **2중 방어선**: WHERE `tenant_id=$1` + RLS `tenant_members` JOIN. 각 migration 직후 수동 테스트 (다른 테넌트 계정으로 접근 시도) |
| 2 | JSON 스키마 동적 렌더러의 Zod 동적 검증 복잡도 | FormField 단일 컴포넌트로 타입 분기 내재화. Zod schema builder 함수 하나로 통일 |
| 3 | 결재 동시성 (동일 문서 두 명이 동시 승인 시도) | `SELECT ... FOR UPDATE` + `status='pending'` 체크. 실패 시 `fail(409)` |
| 4 | 양식 JSON 에디터 UX 부담 (관리자 대상) | MVP는 Monaco + JSON schema 자동완성. 5종 샘플을 복사·편집하는 방식으로 학습곡선 완화 |
| 5 | Storage RLS 누락 | Storage 정책도 `(storage.foldername(name))[1] IN (SELECT tenant_id::text FROM tenant_members WHERE user_id = auth.uid())` 적용 |
| 6 | 첫 기안 UX 마찰 (첫 경험 90초 목표) | 회원가입 → 조직 생성 → inbox 까지 3 페이지, 시스템 양식 5종 자동 시드, "첫 기안 작성" CTA |
| 7 | SMB 고객사는 보통 IT 담당 1명 → JSON 에디터 거부감 | Plan 문서에 기재, 실사용 피드백 후 v2에서 드래그&드롭 빌더 계획 |
| 8 | 결재자 퇴사 시 진행 문서 stuck | v1.0은 퇴사 차단(ON DELETE RESTRICT). v1.1 대결/대체자 지정으로 해결 |

---

## 12. Milestones (v1.0 세부 마일스톤)

| # | 마일스톤 | 산출물 | 검증 |
|---|---|---|---|
| M1 | 프로젝트 스캐폴딩 | SvelteKit 2 + TS + Tailwind + @supabase/ssr + Zod 설치, `src/routes/` 기본 구조, `hooks.server.ts` + `safeGetSession` | 빈 `/login` 접근 가능, 세션 쿠키 왕복 확인 |
| M2 | DB Migration 0001~0005 | profiles + tenants + tenant_members + tenant_invitations + departments | Supabase studio에서 row 확인 |
| M3 | 회원가입 + 테넌트 생성 + 온보딩 | /signup, /onboarding/create-tenant, fn_create_tenant, fn_copy_system_forms | 회원가입 → 테넌트 생성 → inbox 도달 |
| M4 | DB Migration 0006~0010 | approval_forms + documents + steps + attachments + audit + system forms seed | — |
| M5 | RLS 0011 + RPC 0012 | 모든 RLS 정책 + 핵심 plpgsql 함수 | 수동 크로스 테넌트 테스트 |
| M6 | FormRenderer + 기안 작성 | /approval/drafts/new/[formId], FormRenderer, ApproverPicker, 첨부 업로드, fn_submit_draft | 기안 상신 → DB 확인 |
| M7 | 결재함 + 문서 상세 | /approval/inbox 5탭, /approval/documents/[id], ApprovalPanel, AuditTimeline | 승인/반려/회수 전체 플로우 |
| M8 | Admin 3개 페이지 | /admin/forms (JSON 에디터), /admin/org, /admin/members (초대 토큰) | 양식 추가·편집·발행, 초대 링크 생성·수락 |
| M9 | 스모크 테스트 + 버그 수정 | 6개 핵심 시나리오 수동 확인 | 승인률 100% |
| M10 | v1.0 태깅 + dogfood 개시 | Git tag `v1.0.0`, 내부 사용 시작 | 내부 1개 팀 실제 결재 진행 |

---

## 13. Definition of Done (v1.0)

- [ ] 10개 마일스톤 모두 통과
- [ ] 6개 핵심 시나리오 수동 스모크 테스트 통과:
  - 회원가입 → 테넌트 생성 → 기안 → 결재 완료
  - 초대 수락 → 기안 → 결재
  - 한 사용자 N 테넌트 전환
  - 양식 JSON 편집 → 발행 → 신규 기안에 반영
  - 관리자 권한 없는 유저의 /admin 접근 차단 확인
  - 크로스 테넌트 접근 시도 차단 확인 (수동)
- [ ] RLS 정책 누락 없음 (모든 테이블 SELECT/INSERT/UPDATE/DELETE)
- [ ] 모든 mutation이 DB 함수 경유 + 감사 로그 자동 생성
- [ ] 기본 반응형 (모바일 뷰에서 결재함·기안·결재 처리 가능)
- [ ] use:enhance 적용되어 JS-off 환경에서도 결재 처리 가능
- [ ] README.md에 로컬 개발 setup 문서 (Supabase 초기화 + seed 실행)

---

## 14. Out of Scope / Deferred Notes

### v1.1 Korean Exceptions
- 전결권자 테이블 + 상위 단계 자동 skip 로직
- 대결: `user_absences` + 대리자 지정 + pg_cron 자동 전환
- 후결: 문서 상태 `pending_post_facto` + 정규화 절차
- 부재자동: pg_cron으로 휴가 시작/종료 시 위임 트리거

### v1.2 Parallel & Legal
- `approval_steps.parallel_group` 컬럼 + fn_approve_step 분기
- 합의 단계 (step_type='consultation'), 부결 시 문서 반려
- Edge Function: HTML → PDF (Puppeteer), `approval-archives` 버킷
- 완료 문서 SHA256 해시 + `approval_document_archives` 테이블
- 전자서명 이미지 Storage + `user_signatures`

### v1.3 Polish
- Supabase Realtime 채널 구독 (approval_steps 변경)
- 이메일 알림 Edge Function (Resend 또는 Postmark)
- 모바일 UX 전용 CSS + 터치 제스처

### v2.0 Differentiation
- 드래그&드롭 양식 빌더 (소규모 로우코드 엔진)
- 자동결재선 규칙 엔진 (조건부 부서/금액/역할 매칭)
- 전문검색 (pg_trgm or tsvector)

---

## 15. References

- 조사 문서: [docs/01-research/korean-groupware-approval-review.md](../../01-research/korean-groupware-approval-review.md)
- SvelteKit Docs: https://svelte.dev/docs/kit
- @supabase/ssr: https://supabase.com/docs/guides/auth/server-side/sveltekit
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security

---

> **다음 단계**: `/pdca design approval-mvp` — 섹션 8 Data Model과 섹션 7 Components를 실제 실행 가능한 Design 문서로 상세화
