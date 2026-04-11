# Rigel — Claude Code Project Guide

> 이 파일은 세션 시작 시 Claude에 자동 로드됩니다. 프로젝트 고유 규칙·패턴·주의사항.

## 프로젝트 정체성

- **Rigel**: 한국형 SMB용 multi-tenant 전자결재 SaaS
- **현재 상태**: **v1.0.0 Shippable Core** 출시 완료 (git tag `v1.0.0`, commit `d957381`)
- **Phased 로드맵**: v1.0 → v1.1(전결/대결/후결/부재자동) → v1.2(병렬/PDF/해시) → v1.3(Realtime/이메일/모바일) → v2(빌더)

## Stack (변경 금지)

- **Frontend**: SvelteKit 2 + **Svelte 5 (runes)** + TypeScript + Tailwind v3
- **Backend**: `@supabase/ssr` + Supabase local (`http://127.0.0.1:54321`)
- **DB**: Postgres with RLS + plpgsql `SECURITY DEFINER` RPCs
- **Storage**: `approval-attachments` bucket
- **No Next.js**, no Pages Router, no class components. Svelte 5 runes 전용.

## 필수 규칙 (v1.0 교훈 반영 — 위반 시 버그 재발)

### RLS 작성 규칙
1. **`auth.uid()` 는 반드시 `(SELECT auth.uid())` 로 래핑** — InitPlan 캐싱 (Supabase linter `auth_rls_initplan`)
2. **`FOR ALL` 정책 금지** — action별 (SELECT/INSERT/UPDATE/DELETE) 개별 작성
3. **같은 action에 permissive 정책 중복 금지** — OR로 합쳐서 하나만
4. **Helper 함수는 `SECURITY DEFINER + STABLE`** — `is_tenant_member`, `is_document_drafter` 등
5. **테이블 간 양방향 EXISTS 금지** — 한쪽은 SECURITY DEFINER helper로 우회 (RLS 무한 재귀 방지)

### Mutation 규칙
1. **모든 mutation은 `SECURITY DEFINER` RPC 경유** — 직접 INSERT/UPDATE 금지 (`ad_no_direct_insert` 패턴)
2. **감사 로그는 RPC 내부에서 자동 기록** — 호출자 실수 방지
3. **상태 변경 시 `SELECT ... FOR UPDATE`** — race condition 방어
4. **결재선·양식은 스냅샷** — `form_schema_snapshot` + `approval_steps` INSERT로 상신 시점 고정

### Supabase JS 클라이언트 규칙
1. **embed (`foo:bar!inner(...)`)는 직접 FK만 지원** — 경유 관계(tenant_members → auth.users ← profiles)는 **2-query + Map join** 사용 (`src/lib/server/queries/profiles.ts` 참조)
2. **RPC JSONB**: JS object/array 그대로 전달하면 자동 변환. `JSON.stringify` 불필요

### SvelteKit + Svelte 5 규칙
1. **복잡 state 전송**: `<input value={JSON.stringify(state)}>` 대신 `use:enhance={({formData}) => formData.set(...)}` — submit 시점 함수 실행으로 stale 방지
2. **Actions는 `parent()` 없음** — `locals.currentTenant` 도 null. `resolveTenant` helper inline으로 직접 해석
3. **`$state(data.x)` 경고**: `untrack(() => [...data.x])` 로 초기값만 캡처
4. **Form 에러 shape 통일**: `$lib/forms.ts`의 `FormErrors` + `zodErrors()` / `formError()` 사용 — discriminated union 접근 이슈 회피
5. **Hidden input은 primitive 값만** — 객체/배열은 use:enhance에서 주입

### Storage 규칙
- 경로: **`{tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}`** (월 버킷, 파일당 폴더 없음)
- 원본 파일명은 DB `file_name`에만 저장
- 다운로드: `createSignedUrl(path, ttl, { download: fileName })` 로 Content-Disposition 복원
- 클라이언트 업로드 실패 시 Storage orphan 자동 삭제 (catch → remove)

### Auth 사용자 생성 규칙
- **프로덕션/테스트 모두 `/signup` endpoint 경유 권장**
- SQL INSERT로 `auth.users` 생성 시:
  - `encrypted_password = crypt(pw, gen_salt('bf', 10))` — cost 10 필수
  - `confirmation_token`, `recovery_token`, `email_change_token_new` 등 모든 token 필드 `COALESCE(..., '')` — NULL이면 GoTrue 로그인 실패

## 디렉터리 구조 (참고)

```
src/
├── hooks.server.ts                 # Supabase + safeGetSession + authGuard
├── lib/
│   ├── client/uploadAttachment.ts  # 월 버킷 업로드
│   ├── components/                 # 9개 재사용 (FormRenderer, ApprovalLine, ApprovalPanel 등)
│   ├── forms.ts                    # FormErrors 공용 타입
│   ├── server/
│   │   ├── queries/profiles.ts     # 2-query join helper
│   │   ├── schemas/                # Zod (approvalActions, formSchema)
│   │   └── downloadUrl.ts          # signed URL + 원본 파일명
│   └── types/approval.ts           # 도메인 TS 타입
└── routes/
    ├── login/ signup/ logout/ onboarding/ invite/
    └── t/[tenantSlug]/
        ├── +layout.server.ts       # tenant 해석 + membership
        ├── approval/
        │   ├── inbox/              # 5탭
        │   ├── drafts/new/[formCode]/
        │   └── documents/[id]/     # 승인/반려/회수/코멘트
        └── admin/                  # forms/members/org (owner/admin only)
supabase/migrations/                # 0001~0018 + linter fixes
```

## PDCA 문서 위치

| 단계 | 파일 |
|---|---|
| Plan | `docs/01-plan/features/approval-mvp.plan.md` |
| Design | `docs/02-design/features/approval-mvp.design.md` — **RLS 규칙 §2.0, Risk Table §14** |
| Analysis | `docs/03-analysis/approval-mvp.analysis.md` — 25 smoke tests + gap 100% |
| Research | `docs/01-research/korean-groupware-approval-review.md` — 시장조사 |

## 개발 명령

```bash
npm run dev          # http://localhost:5173
npm run check        # svelte-check (0 error 기준)
npm run build        # adapter-node 빌드
```

## Supabase 작업

- **새 migration 추가 시**: `supabase/migrations/00NN_설명.sql` 파일 생성 + Supabase MCP `apply_migration` 적용 + `get_advisors` 로 Security/Performance WARN 확인
- **RLS 적용 후 반드시 advisor 확인** — `auth_rls_initplan`, `multiple_permissive_policies` 0건 필수

## 테스트 계정 (DB에 존재)

| 이메일 | 비밀번호 | 역할 | 테넌트 |
|---|---|---|---|
| m3test1@example.com | testpass1234 | owner | m3test-org |
| m5approver@example.com | testpass1234 | member | m3test-org |
| newuser@example.com | testpass1234 | member | m3test-org |
| admin@example.com | (sign up 본인 비번) | owner | acme |

## v1.1 진입 시 주의

memory (`project_rigel.md`)의 "🚀 v1.1 진입 가이드" 섹션 참조. 주요 scope:
1. 전결 (delegation_rules)
2. 대결 (user_absences + proxy)
3. 후결 (post_facto status + 신규 RPC)
4. 부재자동 전환 (pg_cron 최초 도입)

**모든 v1.0 규칙 그대로 적용**. 새 migration은 `0019~`.

## 주의

- **`.env.local`은 절대 commit 금지** — `.gitignore`에 이미 등록됨
- **기존 v1.0 migration 0001~0018 수정 금지** — 누적만 허용
- **결재 mutation RPC 내부 로직 수정 시 `fn_approve_step`의 Risk #13 주의** (마지막 approval 완료 시 pending reference step 일괄 skipped)
- **Auto-tracker 노이즈**: `.bkit/state/pdca-status.json`의 `activeFeatures` 배열에 파일 경로 기반 가짜 feature (routes/login/[id] 등)가 누적됨. 실제 feature는 `approval-mvp` 하나

## 빠른 참조

- **Plan Plus 재사용**: `/plan-plus 전자결재-v1.1-korean-exceptions`
- **상태 확인**: `/pdca status`
- **완료 보고서**: `/pdca report approval-mvp`
