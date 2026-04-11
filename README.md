# Rigel

> 한국형 전자결재 SaaS (multi-tenant)
> Stack: **SvelteKit 2 + Svelte 5 (runes) + TypeScript + Supabase + Tailwind**

## 개요

Rigel은 국내 SMB(10~300명 규모)를 위한 가벼운 SaaS 전자결재 시스템입니다.
한국형 결재 도메인(기안→결재→참조/공람)의 핵심 흐름을 제공하며, JSON 스키마 기반
동적 양식과 멀티 테넌트 아키텍처를 통해 고객사별 운영 비용을 최소화합니다.

### 차별점

| | Rigel v1.0 | 일반 경쟁사 |
|---|---|---|
| 양식 편집 | **JSON 스키마 + 런타임 렌더러** | 드래그&드롭 빌더 (과도한 복잡도) |
| 멀티 테넌트 | 경로 기반 `/t/{slug}/` 공유 스키마 | 고객사당 배포 or 스키마 복제 |
| 한국형 결재 | 기본 순차 + v1.1에서 전결/대결/후결/부재자동 | 처음부터 풀 스펙 (기능 과잉) |
| 개발 속도 | Phased v1.0 → v1.3 | 빅뱅 릴리스 |

### v1.0 범위

- ✅ 회원가입·로그인·테넌트 생성·초대 플로우
- ✅ JSON 스키마 양식 관리 (5종 시스템 양식 seed)
- ✅ 기안 작성 + 결재선 편집 + 첨부파일 업로드
- ✅ 결재함 (5탭: 대기/진행/완료/반려/임시저장)
- ✅ 승인/반려/회수/코멘트
- ✅ 감사 로그 + 이력 타임라인
- ✅ 멀티 테넌트 격리 (RLS 이중 방어선)
- ✅ 관리자 페이지 (양식/멤버/부서)

v1.1~1.3 로드맵은 [`docs/01-plan/features/approval-mvp.plan.md`](docs/01-plan/features/approval-mvp.plan.md) 섹션 0 참조.

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
# 모든 migration 순차 적용 (supabase/migrations/ 아래 0001~0018)
supabase db reset
```

또는 개별 migration을 Supabase Studio나 MCP로 적용 (migration은 순서대로 idempotent하게 설계됨).

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

| 단계 | 파일 |
|---|---|
| Plan | [docs/01-plan/features/approval-mvp.plan.md](docs/01-plan/features/approval-mvp.plan.md) |
| Design | [docs/02-design/features/approval-mvp.design.md](docs/02-design/features/approval-mvp.design.md) |
| Analysis | [docs/03-analysis/approval-mvp.analysis.md](docs/03-analysis/approval-mvp.analysis.md) |
| Research | [docs/01-research/korean-groupware-approval-review.md](docs/01-research/korean-groupware-approval-review.md) |

---

## 프로젝트 구조

```
.
├── .vscode/              # launch.json + 확장 추천
├── supabase/
│   └── migrations/       # 18 migrations + linter fixes
├── src/
│   ├── app.html
│   ├── app.css
│   ├── app.d.ts          # App.Locals 타입
│   ├── hooks.server.ts   # Supabase 서버 클라이언트 + safeGetSession + authGuard
│   ├── lib/
│   │   ├── client/
│   │   │   └── uploadAttachment.ts
│   │   ├── components/   # 9 재사용 컴포넌트
│   │   ├── forms.ts      # FormErrors + zodErrors/formError helper
│   │   ├── server/
│   │   │   ├── queries/  # fetchProfilesByIds (2-query join pattern)
│   │   │   ├── schemas/  # Zod (approvalActions, formSchema)
│   │   │   └── downloadUrl.ts
│   │   └── types/
│   │       └── approval.ts  # 도메인 TS 타입
│   └── routes/
│       ├── +page.server.ts           # entry redirect (tenant 해석)
│       ├── login, signup, logout     # 인증
│       ├── onboarding/create-tenant/ # 첫 조직 생성
│       ├── invite/[token]/           # 초대 수락 (anon 허용)
│       └── t/[tenantSlug]/
│           ├── +layout.server.ts     # tenant 해석 + membership 검증
│           ├── approval/
│           │   ├── inbox/            # 5탭 결재함
│           │   ├── drafts/new/[formCode]/  # 기안 작성
│           │   └── documents/[id]/   # 문서 상세 + 4 actions
│           └── admin/                # 관리자 (owner/admin only)
│               ├── forms/            # 양식 CRUD + JSON 에디터
│               ├── members/          # 초대/역할/제거
│               └── org/              # 부서 CRUD (v1.0 flat)
└── docs/                 # PDCA 문서
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
