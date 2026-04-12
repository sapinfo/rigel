# Rigel

> 한국형 전자결재 SaaS (multi-tenant)
> Stack: **SvelteKit 2 + Svelte 5 (runes) + TypeScript + Supabase + Tailwind**

## 개요

Rigel은 국내 SMB(10~300명 규모)를 위한 가벼운 SaaS 전자결재 시스템입니다.
한국형 결재 도메인(기안→결재→참조/공람)의 핵심 흐름을 제공하며, JSON 스키마 기반
동적 양식과 멀티 테넌트 아키텍처를 통해 고객사별 운영 비용을 최소화합니다.

### 차별점

| | Rigel v1.1 | 일반 경쟁사 |
|---|---|---|
| 양식 편집 | **JSON 스키마 + 런타임 렌더러** | 드래그&드롭 빌더 (과도한 복잡도) |
| 멀티 테넌트 | 경로 기반 `/t/{slug}/` 공유 스키마 | 고객사당 배포 or 스키마 복제 |
| 한국형 결재 | 순차 + **전결/대결/후결/부재자동 (v1.1 완료)** | 처음부터 풀 스펙 (기능 과잉) |
| 개발 속도 | Phased v1.0 → v1.3 | 빅뱅 릴리스 |

### v1.0 범위 (완료 — tag `v1.0.0`)

- ✅ 회원가입·로그인·테넌트 생성·초대 플로우
- ✅ JSON 스키마 양식 관리 (5종 시스템 양식 seed)
- ✅ 기안 작성 + 결재선 편집 + 첨부파일 업로드
- ✅ 결재함 (5탭: 대기/진행/완료/반려/임시저장)
- ✅ 승인/반려/회수/코멘트
- ✅ 감사 로그 + 이력 타임라인
- ✅ 멀티 테넌트 격리 (RLS 이중 방어선)
- ✅ 관리자 페이지 (양식/멤버/부서)

### v1.1 범위 (완료 — tag `v1.1.0`)

- ✅ **전결 (Delegation)**: 금액·양식별 자동 위임 규칙 (`delegation_rules` + `fn_submit_draft v2`)
- ✅ **대결 (Proxy Approval)**: 부재 등록 시 대리인 승인 (`fn_approve_with_proxy`, 체인 깊이 ≥ 2 거부)
- ✅ **후결 (Post-facto Submission)**: 긴급건 먼저 집행 → 사후 상신 (`fn_submit_post_facto`, 상태 `pending_post_facto`)
- ✅ **부재자동 전환**: 부재 INSERT/UPDATE 시 trigger + 매일 00:00 KST pg_cron 백업 이중화
- ✅ 관리자: `/admin/delegations`, `/admin/absences` + 사용자 self-service `/my/absences`
- ✅ 13/15 smoke pass, match 94%

v1.2~1.3 로드맵은 [`docs/01-plan/features/approval-mvp.plan.md`](docs/01-plan/features/approval-mvp.plan.md) 섹션 0 참조.
v1.1 PDCA 문서 아카이브: [`docs/archive/2026-04/전자결재-v1.1-korean-exceptions/`](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/) — **design.md 는 [`ERRATA.md`](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/ERRATA.md)와 함께 읽어야 함** (signature drift 존재).

---

## 로컬 개발 환경 설정

### 사전 요구

- **Node.js 22+** (권장 24)
- **npm 10+**
- **Docker** (Supabase local 실행용)
- **Supabase CLI** (`brew install supabase/tap/supabase` on macOS)

### 1. Supabase 기동

```bash
# 프로젝트 루트에서 (기존 Supabase 인스턴스 있다면 생략)
supabase start
```

Supabase local URL: `http://127.0.0.1:54321`
Studio URL: `http://127.0.0.1:54323`

### 2. 의존성 설치

```bash
npm install
```

### 3. 환경변수 설정

```bash
cp .env.example .env.local
```

`.env.local` 편집 — `PUBLIC_SUPABASE_ANON_KEY`에 `supabase status` 출력의 anon key를 붙여넣기.

### 4. DB 마이그레이션 적용

```bash
# 모든 migration 순차 적용 (supabase/migrations/ 아래 0001~0030)
supabase db reset
```

또는 개별 migration을 Supabase Studio나 MCP로 적용 (migration은 순서대로 idempotent하게 설계됨).

**v1.1 부터 `pg_cron` 확장이 필요합니다** (migration 0030 에서 `CREATE EXTENSION IF NOT EXISTS pg_cron` 실행).

- **Supabase local**: 기본 이미지에 포함되어 있어 별도 설정 불필요 (`supabase db reset` 한 번으로 활성화됨)
- **Supabase Cloud (Pro+)**: Dashboard → Database → Extensions 에서 `pg_cron` 활성화 후 `supabase db push`
- **시간대 주의**: `pg_cron` 은 **UTC 기준**. `0030_pg_cron_absence_backup.sql` 의 cron expression `0 15 * * *` 는 KST 00:00 (전날 UTC 15:00) 임. 운영 리전 변경 시 재검토 필수.
- **확인**: `SELECT * FROM cron.job;` — `absence_auto_delegate_daily` 1건 등록되어야 함.

### 5. 개발 서버 실행

```bash
npm run dev
# → http://localhost:5173
```

### 6. 빌드·검증

```bash
npm run check     # svelte-check (TS + Svelte)
npm run build     # 프로덕션 빌드 (adapter-node)
npm run preview   # 빌드 결과 미리보기
```

### 7. 스모크 테스트 (선택)

v1.1 에 도입된 경계 케이스 (위임 체인 깊이, 후결 빈 사유) 를 자동 검증하려면:

```bash
# supabase db reset 직후, seed 데이터가 로드된 상태에서 실행
psql "$(supabase status -o json | jq -r '.DB_URL // "postgresql://postgres:postgres@127.0.0.1:54322/postgres"')" \
  -v ON_ERROR_STOP=1 \
  -f tests/smoke/v1.1-korean-exceptions.sql
```

모든 `ASSERT` 통과 시 조용히 끝납니다. 스모크는 단일 TX 로 실행되며 말미에 `ROLLBACK` 하므로 DB 상태를 변경하지 않습니다.

---

## VSCode 디버깅

F5로 서버사이드 + Chrome 디버거 동시 기동:

1. `Run & Debug` 패널 열기 (⇧⌘D)
2. 드롭다운에서 **"F5: Full Stack (Server + Chrome)"** 선택
3. F5 키

브레이크포인트를 어디든 찍을 수 있음:
- `src/hooks.server.ts` (요청마다)
- `src/routes/**/+page.server.ts` (SSR load, form actions)
- `src/routes/**/+page.svelte` (클라이언트 하이드레이션 후)

자세한 내용: [`.vscode/launch.json`](.vscode/launch.json)

---

## 아키텍처 요약

### 스택 계층

```
Browser (Svelte 5 runes + Tailwind)
    ↓ use:enhance, form actions
SvelteKit 2 Server (Node)
    ├─ hooks.server.ts (Supabase SSR + safeGetSession + authGuard)
    ├─ /t/[tenantSlug]/+layout.server.ts (tenant 해석 + membership 검증)
    └─ +page.server.ts (load / actions)
    ↓ @supabase/ssr (cookie-based)
Supabase Local
    ├─ Postgres (RLS + plpgsql SECURITY DEFINER RPCs)
    ├─ Auth (email+password)
    └─ Storage (approval-attachments, {tenant_id}/{YYYY-MM}/{uuid}.ext)
```

### 이중 방어선 (권한)

1. **DB RLS** — 모든 테이블에 `tenant_members` join 기반 정책
2. **Server Action** — `locals.user` null 체크 + `resolveTenant` membership 재확인
3. **plpgsql RPC** — `SECURITY DEFINER` 함수 내부에서 step 소유권·상태 최종 검증

### 핵심 원칙

1. **양식·결재선은 스냅샷** — 상신 시점에 `form_schema_snapshot` / `approval_steps` 로 고정 → 양식 수정/인사발령의 영향에서 격리
2. **모든 mutation은 RPC 경유** — `fn_save_draft`/`fn_submit_draft`/`fn_approve_step` 등. audit 로그 자동 기록
3. **`(SELECT auth.uid())` 래핑** — RLS 정책의 `auth_rls_initplan` 성능 최적화
4. **action별 정책 분리** — `FOR ALL` 금지, `multiple_permissive_policies` 방지
5. **SECURITY DEFINER helper** — `is_tenant_member`, `is_document_drafter` 등으로 RLS 재귀 방지

상세: [`docs/02-design/features/approval-mvp.design.md`](docs/02-design/features/approval-mvp.design.md)

---

## PDCA 문서

### v1.0 (완료, `v1.0.0`)

| 단계 | 파일 |
|---|---|
| Plan | [docs/01-plan/features/approval-mvp.plan.md](docs/01-plan/features/approval-mvp.plan.md) |
| Design | [docs/02-design/features/approval-mvp.design.md](docs/02-design/features/approval-mvp.design.md) |
| Analysis | [docs/03-analysis/approval-mvp.analysis.md](docs/03-analysis/approval-mvp.analysis.md) |

### v1.1 (완료, `v1.1.0`, 아카이브됨)

| 단계 | 파일 |
|---|---|
| Plan | [docs/archive/2026-04/전자결재-v1.1-korean-exceptions/plan.md](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/plan.md) |
| Design | [docs/archive/2026-04/전자결재-v1.1-korean-exceptions/design.md](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/design.md) |
| **Errata** | [docs/archive/2026-04/전자결재-v1.1-korean-exceptions/ERRATA.md](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/ERRATA.md) (drift 보정) |
| Analysis | [docs/archive/2026-04/전자결재-v1.1-korean-exceptions/analysis.md](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/analysis.md) |
| Report | [docs/archive/2026-04/전자결재-v1.1-korean-exceptions/report.md](docs/archive/2026-04/전자결재-v1.1-korean-exceptions/report.md) |

### 기타

| 자료 | 파일 |
|---|---|
| Research | [docs/01-research/korean-groupware-approval-review.md](docs/01-research/korean-groupware-approval-review.md) |

---

## 프로젝트 구조

```
.
├── .vscode/              # launch.json + 확장 추천
├── supabase/
│   └── migrations/       # 30 migrations (0001~0030)
├── tests/
│   └── smoke/            # psql ASSERT-기반 smoke (v1.1~)
├── src/
│   ├── app.html
│   ├── app.css
│   ├── app.d.ts          # App.Locals 타입
│   ├── hooks.server.ts   # Supabase 서버 클라이언트 + safeGetSession + authGuard
│   ├── lib/
│   │   ├── absenceTypes.ts            # v1.1 client-safe absence enum/label
│   │   ├── client/
│   │   │   └── uploadAttachment.ts
│   │   ├── components/                # 재사용 컴포넌트
│   │   ├── forms.ts                   # FormErrors + zodErrors/formError helper
│   │   ├── server/
│   │   │   ├── queries/               # profiles, delegations, absences (2-query join)
│   │   │   ├── schemas/                # Zod (approvalActions, formSchema, delegationRule, absence)
│   │   │   └── downloadUrl.ts
│   │   └── types/
│   │       └── approval.ts            # 도메인 TS 타입 (v1.1 enum 확장 포함)
│   └── routes/
│       ├── +page.server.ts            # entry redirect (tenant 해석)
│       ├── login, signup, logout      # 인증
│       ├── onboarding/create-tenant/  # 첫 조직 생성
│       ├── invite/[token]/            # 초대 수락 (anon 허용)
│       └── t/[tenantSlug]/
│           ├── +layout.server.ts      # tenant 해석 + membership 검증
│           ├── my/absences/           # v1.1 self-service 부재 등록
│           ├── approval/
│           │   ├── inbox/             # 5탭 (pending_post_facto 포함)
│           │   ├── drafts/new/[formCode]/  # 기안 작성 + 후결 토글
│           │   └── documents/[id]/    # 문서 상세 + 대리/전결 배지
│           └── admin/                 # 관리자 (owner/admin only)
│               ├── forms/             # 양식 CRUD + JSON 에디터
│               ├── members/           # 초대/역할/제거
│               ├── org/               # 부서 CRUD
│               ├── delegations/       # v1.1 전결 규칙 CRUD
│               └── absences/          # v1.1 멤버 부재 관리
└── docs/                 # PDCA 문서 + archive
```

---

## 기여·규칙

- 새 mutation은 반드시 `SECURITY DEFINER` RPC로
- 새 RLS 정책은 M2 규칙 준수 (`(SELECT auth.uid())`, FOR ALL 금지)
- Svelte 5 `$state`로 복잡 객체 전송 시 `use:enhance({formData}) => formData.set(...)` 패턴 사용
- Supabase JS embed는 **직접 FK가 있는 경우에만** 사용. 경유 관계는 2-query
- 테스트용 auth.users 생성 시 `gen_salt('bf', 10)` + token 필드 `COALESCE(..., '')` 필요

## 라이센스

TBD (private for now)
