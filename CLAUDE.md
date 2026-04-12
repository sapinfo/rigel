# Rigel — Claude Code Project Guide

> 이 파일은 세션 시작 시 Claude에 자동 로드됩니다. 프로젝트 고유 규칙·패턴·주의사항.

## 프로젝트 정체성

- **Rigel**: 한국형 SMB용 multi-tenant 전자결재 SaaS
- **현재 상태**: **v1.2.0** 병렬/PDF/해시/서명 완료 (commit `8b60fb6`)
  - v1.0.0 (`d957381`): Shippable Core (25 smoke, match 100%)
  - v1.1.0 (`cb703d7`): 전결/대결/후결/부재자동 (13/15 smoke, match 94%)
  - v1.2.0 (`8b60fb6`): 병렬결재/PDF/해시/서명 (33+ Vitest, match 90%)
- **Phased 로드맵**: v1.0 ✅ → v1.1 ✅ → v1.2 ✅ → v1.3(Realtime/이메일/모바일) → v2(빌더)

## Stack (변경 금지)

- **Frontend**: SvelteKit 2 + **Svelte 5 (runes)** + TypeScript + Tailwind v3
- **Backend**: `@supabase/ssr` + Supabase local (`http://127.0.0.1:54321`)
- **DB**: Postgres with RLS + plpgsql `SECURITY DEFINER` RPCs
- **Storage**: `approval-attachments` bucket
- **No Next.js**, no Pages Router, no class components. Svelte 5 runes 전용.

## 필수 규칙 (v1.0 + v1.1 교훈 반영 — 위반 시 버그 재발)

### RLS 작성 규칙
1. **`auth.uid()` 는 반드시 `(SELECT auth.uid())` 로 래핑** — InitPlan 캐싱 (Supabase linter `auth_rls_initplan`)
2. **`FOR ALL` 정책 금지** — action별 (SELECT/INSERT/UPDATE/DELETE) 개별 작성
3. **같은 action에 permissive 정책 중복 금지** — OR로 합쳐서 하나만
4. **Helper 함수는 `SECURITY DEFINER + STABLE`** — `is_tenant_member`, `is_document_drafter` 등
5. **테이블 간 양방향 EXISTS 금지** — 한쪽은 SECURITY DEFINER helper로 우회 (RLS 무한 재귀 방지)

### Mutation 규칙
1. **모든 approval mutation은 `SECURITY DEFINER` RPC 경유** — 직접 INSERT/UPDATE 금지 (`ad_no_direct_insert` 패턴). 단 config 테이블 (delegation_rules, user_absences)은 RLS 게이트로 직접 CRUD 허용
2. **감사 로그는 RPC 내부에서 자동 기록** — 호출자 실수 방지
3. **상태 변경 시 `SELECT ... FOR UPDATE`** — race condition 방어. 후결 시 `SELECT form FOR UPDATE`로 snapshot 락 명시
4. **결재선·양식은 스냅샷** — `form_schema_snapshot` + `approval_steps` INSERT로 상신 시점 고정. delegation 매칭 결과도 snapshot (이후 rule 변경 영향 없음)

### Postgres enum 규칙 (v1.1 M12 교훈)
1. **`ALTER TYPE ... ADD VALUE`는 TX 외부에서만** — migration 파일 단독 분리 (예: `0020_audit_action_delegated.sql`). PG 12+는 같은 TX에서 추가 후 사용 불가.
2. **CASE/COALESCE 결과가 enum 컬럼에 들어갈 때는 명시 캐스트 필수**:
   ```sql
   -- ❌ BAD (text로 resolve → INSERT 실패)
   INSERT INTO audit_logs (action) VALUES
     (CASE WHEN proxy IS NULL THEN 'approve' ELSE 'approved_by_proxy' END);

   -- ✅ GOOD
   INSERT INTO audit_logs (action) VALUES
     ((CASE WHEN proxy IS NULL THEN 'approve' ELSE 'approved_by_proxy' END)::public.audit_action);
   ```
   단일 리터럴 INSERT (`VALUES (..., 'approve', ...)`)는 implicit cast OK.
3. **새 enum 값 도입 시 4곳 동시 업데이트**:
   - `src/lib/types/approval.ts` union 타입
   - `Record<EnumType, string>` label map (DocumentHeader, inbox, AuditTimeline 등)
   - 관련 RLS/RPC에서 WHERE 절 / IN() 사용 지점
   - 검사: `grep -rn "'<기존 enum 값>'" src/` 로 누락 지점 확인

### pg_cron 규칙 (v1.1 M14 교훈)
1. **UTC 기준** — KST 00:00은 `0 15 * * *` (UTC 15:00 전날). cron expression에 주석 필수
2. **Idempotent migration** — 재실행 안전하도록 `unschedule` 후 재등록:
   ```sql
   DO $$ BEGIN
     IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = '...') THEN
       PERFORM cron.unschedule('...');
     END IF;
   END $$;
   SELECT cron.schedule('...', '0 15 * * *', $cmd$ ... $cmd$);
   ```
3. **Trigger + cron 이중화** — 즉시 반응 + 누락 복구. trigger가 본 테이블을 UPDATE 하지 않도록 재귀 방지

### Supabase JS 클라이언트 규칙
1. **embed (`foo:bar!inner(...)`)는 직접 FK만 지원** — 경유 관계(tenant_members → auth.users ← profiles)는 **2-query + Map join** 사용 (`src/lib/server/queries/profiles.ts` 참조)
2. **RPC JSONB**: JS object/array 그대로 전달하면 자동 변환. `JSON.stringify` 불필요

### SvelteKit + Svelte 5 규칙
1. **복잡 state 전송**: `<input value={JSON.stringify(state)}>` 대신 `use:enhance={({formData}) => formData.set(...)}` — submit 시점 함수 실행으로 stale 방지
2. **Actions는 `parent()` 없음** — `locals.currentTenant` 도 null. `resolveTenant` helper inline으로 직접 해석
3. **`$state(data.x)` 경고**: `untrack(() => [...data.x])` 로 초기값만 캡처
4. **Form 에러 shape 통일**: `$lib/forms.ts`의 `FormErrors` + `zodErrors()` / `formError()` 사용 — discriminated union 접근 이슈 회피
5. **Hidden input은 primitive 값만** — 객체/배열은 use:enhance에서 주입
6. **`$lib/server/*` 는 server-only** (v1.1 M12 교훈) — `.svelte` 파일에서 import 금지 ("An impossible situation occurred" Vite 오류). 클라이언트에서도 필요한 const/enum/label은 `$lib/` 루트에 client-safe 모듈로 분리 (예: `$lib/absenceTypes.ts` ↔ `$lib/server/schemas/absence.ts` re-export)
7. **Label 접근성**: `<label>`과 input은 nesting (`<label><span>title</span><input/></label>`) 또는 for/id 연결. 형제 배치는 svelte-check `a11y_label_has_associated_control` 경고
8. **새 enum 값 추가 후** `Record<EnumType, T>` 매핑 누락 → svelte-check가 잡아줌 → **절대 ignore 하지 말 것**

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
│   ├── absenceTypes.ts             # v1.1 client-safe absence enum/label
│   ├── client/uploadAttachment.ts  # 월 버킷 업로드
│   ├── components/                 # FormRenderer, ApprovalLine, ApprovalPanel, DocumentHeader, AuditTimeline 등
│   ├── forms.ts                    # FormErrors 공용 타입
│   ├── server/
│   │   ├── queries/                # profiles.ts (2-query join), delegations.ts, absences.ts
│   │   ├── schemas/                # Zod (approvalActions, formSchema, delegationRule, absence)
│   │   └── downloadUrl.ts          # signed URL + 원본 파일명
│   └── types/approval.ts           # 도메인 TS 타입 (DocumentStatus, AuditAction 확장)
└── routes/
    ├── login/ signup/ logout/ onboarding/ invite/
    └── t/[tenantSlug]/
        ├── +layout.server.ts       # tenant 해석 + membership
        ├── my/
        │   └── absences/           # v1.1 self-service 부재 등록
        ├── approval/
        │   ├── inbox/              # 5탭 (in_progress + pending_post_facto 포함)
        │   ├── drafts/new/[formCode]/  # 후결 토글 + reason
        │   └── documents/[id]/     # 승인/반려/회수/코멘트 + 대리/전결 배지
        └── admin/
            ├── forms/ members/ org/      # v1.0 관리
            ├── delegations/              # v1.1 전결 규칙 CRUD
            └── absences/                 # v1.1 멤버 부재 관리
supabase/migrations/                # 0001~0037
```

## PDCA 문서 위치

### v1.0 (completed)
| 단계 | 파일 |
|---|---|
| Plan | `docs/01-plan/features/approval-mvp.plan.md` |
| Design | `docs/02-design/features/approval-mvp.design.md` — **RLS 규칙 §2.0, Risk Table §14** |
| Analysis | `docs/03-analysis/approval-mvp.analysis.md` — 25 smoke tests + gap 100% |

### v1.1 (archived)
| 단계 | 파일 |
|---|---|
| All | `docs/archive/2026-04/전자결재-v1.1-korean-exceptions/` — Match 94% |

### v1.2 (archived)
| 단계 | 파일 |
|---|---|
| All | `docs/archive/2026-04/전자결재-v1.2-parallel-pdf-hash-signature/` — Match 90% |

### 공통
| 자료 | 파일 |
|---|---|
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

## v1.1 핵심 정책 (고정, 수정 금지)

| 정책 | 값 | 출처 |
|---|---|---|
| 전결 ↔ 부재 충돌 | **부재 > 전결** (submit 시 delegation skip, approve 시 proxy 체크 — 자연 배타) | Plan §1.4 |
| 후결 원자성 | 단일 TX + `SELECT form FOR UPDATE` + reason 초입 검증 | `0026_fn_post_facto.sql` |
| 부재 자동 전환 | Trigger (AFTER INSERT/UPDATE) + 매일 00:00 KST pg_cron 백업 이중화 | `0029, 0030` |
| 위임 체인 깊이 | depth ≥ 2 `RAISE EXCEPTION` | `0024 fn_approve_step` |
| delegation 매칭 ORDER BY | `(form_id IS NULL) ASC, amount_limit ASC NULLS LAST, effective_from DESC LIMIT 1` | `0021, 0026` |
| 모든 step delegated edge | RAISE 아닌 **자동 completed** + audit `{auto_completed:true}` | `0021 fn_submit_draft v2` |
| pg_cron extension | `CREATE EXTENSION IF NOT EXISTS pg_cron;` — Rigel 첫 도입 | `0030` |

## v1.2 진입 시 주의

memory `project_rigel.md`의 "v1.1 완료" 섹션 참조. 잔여 작업:
1. **G2**: Design §2.3 fn_submit_draft signature errata
2. **G3**: `supabase/config.toml` 또는 README pg_cron 섹션
3. **G4 (Risk #7)**: `fn_advance_document` helper 분리 — 0021/0024/0026 3곳 inline 중복
4. **G5**: `DocumentSteps.svelte` 공용 컴포넌트 분리
5. **G7**: S33(체인 깊이)/S36(빈 사유) SQL smoke 자동화

**v1.2 신규 scope**: 병렬결재(parallel_groups) + PDF 출력 + 본문 해시 + 서명이미지. 새 migration은 `0031~`.

**모든 v1.0/v1.1 규칙 그대로 적용**.

## 주의

- **`.env.local`은 절대 commit 금지** — `.gitignore`에 이미 등록됨
- **기존 v1.0/v1.1 migration 0001~0030 수정 금지** — 누적만 허용
- **결재 mutation RPC 내부 로직 수정 시**:
  - `fn_approve_step`의 Risk #13 주의 (마지막 approval 완료 시 pending reference step 일괄 skipped)
  - v1.1 M13 확장 — 상태 체크는 `status NOT IN ('in_progress', 'pending_post_facto')`로 후결 문서도 포함
  - CASE 결과 `::public.audit_action` 캐스트 유지
- **Auto-tracker 노이즈**: `.bkit/state/pdca-status.json`의 `activeFeatures` 배열에 파일 경로 기반 가짜 feature가 누적됨. 실제 feature는 `전자결재-v1.1-korean-exceptions` (primary) + `approval-mvp` (v1.0 완료)
- **Auto-memory 신뢰 금지**: bkit 자동 메모리가 outdated 체크리스트를 추가할 수 있음. 수정 후 `grep`으로 실제 상태 확인 필수

## 빠른 참조

- **Plan Plus 재사용**: `/plan-plus 병렬결재-v1.2` (v1.2 진입 시)
- **상태 확인**: `/pdca status`
- **v1.1 완료 보고서**: `docs/04-report/features/전자결재-v1.1-korean-exceptions.report.md`
- **Supabase MCP**: `mcp__supabase-local__list_migrations / apply_migration / get_advisors / execute_sql`
- **Git tags**: `v1.0.0` (`d957381`) · `v1.1.0` (`cb703d7`)
