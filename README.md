# Rigel

> **재미 한국기업을 위한 오픈소스 그룹웨어**
> 한국식 전자결재 + 게시판 + 일정 + 근태 + 인사 — 서버 한 대면 무료로 운영

Stack: **SvelteKit 2 + Svelte 5 (runes) + TypeScript + Supabase + Tailwind v3**

---

## 왜 Rigel인가?

미국에서 일하는 한국 기업에는 **한국식 결재 체계**가 필요합니다.
DocuSign, Monday.com, Jira로는 전결/대결/후결/합의/병렬결재를 구현할 수 없습니다.

Rigel은:
- **완전 무료** — 오픈소스, 사용자 수 제한 없음
- **셀프 호스팅** — 데이터가 외부로 나가지 않음
- **한국형 결재 완벽 지원** — 전결, 대결, 후결, 합의, 병렬결재, 감사 추적
- **올인원 그룹웨어** — 결재 + 게시판 + 공지 + 일정 + 근태 + 인사

---

## 기능

### 전자결재
- 양식 빌더 (JSON 스키마 기반 동적 폼)
- 결재선 자동 구성 + 규칙 엔진 + 즐겨찾기/템플릿
- 전결, 대결, 후결, 합의, 병렬결재
- 일괄 결재, 재기안, 독촉
- PDF 출력, SHA-256 해시, 전자서명
- 실시간 알림 (Supabase Realtime)
- 감사 로그 타임라인

### 그룹웨어 (v3.1)
- 게시판 (전사/부서별, 공지 고정, 댓글)
- 공지사항 (필독 배지, 팝업 공지, 읽음 확인)
- 일정관리 (개인/부서/전사 캘린더)
- 회의실 예약 (시간 겹침 자동 방지)
- 근태관리 (출퇴근, 지각 자동 판정, 월간 리포트)
- 인사 프로필 (사번, 직급, 연락처)
- 조직도 + 부서 트리

### 관리자
- 멤버/조직/양식/결재선 규칙/템플릿 관리
- 전결 규칙/부재 관리
- 게시판/공지/회의실/근태 관리
- 감사 로그 뷰어

---

## 버전 히스토리

| 버전 | 주요 내용 | Match Rate |
|---|---|---|
| v1.0 | Shippable Core — 기안/결재/결재함/감사로그 | 100% |
| v1.1 | 전결/대결/후결/부재자동 (한국형 결재 4종) | 94% |
| v1.2 | 병렬결재/PDF 출력/본문 해시/서명이미지 | 90% |
| v1.3 | 실시간 알림/이메일/반응형/PWA | 91% |
| v2.0 | 양식 빌더/결재선 규칙 엔진/버전 관리/조건부 필드 | 78% |
| v2.1 | RuleBuilder GUI/OrgTree/프리뷰/시뮬레이터 | 93% |
| v2.2 | 즐겨찾기/일괄결재/합의/대시보드/감사로그 (12 마일스톤) | 93% |
| v2.3 | StampLine/이관/보관기한/보안등급 | 92% |
| v3.0 | AdminNav/Tiptap 리치에디터/메타데이터/휴가캘린더 | 95% |
| **v3.1** | **게시판/공지/일정/근태/인사/사이드바** | **98%** |

> v4.0 후보 (보류): AI 문서 요약/결재선 추천, Webhook/API 연동, 사내 메신저, 모바일 앱

---

## 데모

| 계정 | 비밀번호 | 역할 |
|---|---|---|
| m3test1@example.com | testpass1234 | 관리자 (owner) |
| m5approver@example.com | testpass1234 | 결재자 (member) |
| newuser@example.com | testpass1234 | 일반 사용자 (member) |

> 데모 데이터는 매일 자정(KST) 자동 리셋됩니다.

---

## 프로덕션 설치 (권장)

IT 전문 인력 없이도 설치 가능합니다. Docker가 설치된 서버/PC 한 대면 충분합니다.

### 사전 요구

- **Podman (권장)** 또는 Docker
- **Git**
- 서버 또는 PC (CPU 4코어, RAM 16GB 이상)

**Podman 설치 (권장 — 무료, 가벼움):**
- Linux: https://podman.io/getting-started/installation
- macOS: `brew install podman`
- Windows: https://podman.io/getting-started/installation
  - 추가 필요: [WSL](https://learn.microsoft.com/windows/wsl/install) + [Python](https://www.python.org/downloads/) 설치 후 `pip install podman-compose`

**Docker 설치 (대안):**
- https://docs.docker.com/get-docker/

### 방법 1: 원클릭 설치

터미널에서 한 줄만 실행하면 소스 다운로드 → 보안 키 자동 생성 → 서버 실행까지 전부 자동입니다.

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/sapinfo/rigel/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/sapinfo/rigel/main/install.ps1 | iex
```

완료되면 `http://서버IP:3000` 접속 → 회원가입 → 조직 생성 → 사용 시작!

### 방법 2: 수동 설치

```bash
# 1. 소스 받기
git clone https://github.com/sapinfo/rigel.git && cd rigel

# 2. 환경변수 설정 (보안 키는 install.sh가 자동 생성해주지만, 수동 시 직접 편집)
cp .env.production.example .env
# .env 파일을 열어서 POSTGRES_PASSWORD, JWT_SECRET 등 설정

# 3. 실행
docker compose up -d

# 4. 접속
# http://서버IP:3000
```

### 자주 쓰는 명령어

```bash
docker compose down          # 중지
docker compose restart       # 재시작
docker compose logs -f app   # 로그 확인
git pull && docker compose up -d --build  # 업데이트
```

> 데이터는 Docker volume에 영구 저장됩니다. 중지해도 데이터는 유지됩니다.

---

## 개발 환경 설치

소스 수정·기여를 위한 로컬 개발 환경입니다.

### 사전 요구

- Docker
- Node.js 22+
- Supabase CLI (`brew install supabase/tap/supabase`)

### 설치 단계

```bash
# 1. 소스 받기
git clone https://github.com/sapinfo/rigel.git && cd rigel

# 2. Supabase 기동 + DB 초기화
supabase start
supabase db reset   # 71개 migration 적용 + seed 데이터 생성

# 3. 환경변수
cp .env.example .env.local
# supabase status 출력의 ANON_KEY, URL을 .env.local에 입력

# 4. 실행
npm install
npm run dev
# → http://localhost:5173
```

### 테스트 계정 (seed 데이터)

| 계정 | 비밀번호 | 역할 |
|---|---|---|
| m3test1@example.com | testpass1234 | 관리자 (owner) |
| m5approver@example.com | testpass1234 | 결재자 (member) |
| newuser@example.com | testpass1234 | 일반 사용자 (member) |

### 빌드·검증

```bash
npm run check     # svelte-check (0 error 기준)
npm run build     # 프로덕션 빌드 (adapter-node)
```

---

## 기술 스택

```
Browser (Svelte 5 runes + Tailwind v3)
    ↓ use:enhance, form actions
SvelteKit 2 Server (Node, adapter-node)
    ├─ hooks.server.ts (Supabase SSR + authGuard)
    ├─ /t/[tenantSlug]/+layout.server.ts (tenant 해석)
    └─ +page.server.ts (load / actions)
    ↓ @supabase/ssr (cookie-based)
Supabase
    ├─ Postgres (RLS + SECURITY DEFINER RPCs)
    ├─ Auth (email+password)
    ├─ Storage (approval-attachments, groupware-attachments)
    ├─ Realtime (notifications)
    └─ pg_cron (부재자동, 데모 리셋)
```

---

## 프로젝트 구조

```
src/
├── hooks.server.ts              # Supabase + authGuard
├── lib/
│   ├── components/              # 11개 공용 컴포넌트
│   ├── client/                  # 클라이언트 유틸 (업로드)
│   ├── types/                   # 도메인 타입 (approval, groupware)
│   └── server/                  # server-only (Zod, queries)
└── routes/
    ├── +page.svelte             # 랜딩페이지 (비로그인)
    ├── login/ signup/ logout/
    └── t/[tenantSlug]/
        ├── +layout.svelte       # 사이드바 레이아웃
        ├── approval/            # 전자결재
        ├── boards/              # 게시판
        ├── announcements/       # 공지사항
        ├── calendar/            # 일정 + 회의실
        ├── attendance/          # 근태관리
        ├── my/profile/          # 인사 프로필
        └── admin/               # 관리자 (13개 메뉴)

supabase/
├── migrations/   # 0001~0071 (71개)
├── seed.sql      # 테스트 데이터 전체
└── seed_helpers.sql
```

---

## Seed 데이터

`supabase db reset` 한 번이면 항상 동일한 상태로 복원:

| 데이터 | 수량 |
|---|---|
| 테스트 계정 | 3명 |
| 테넌트/부서/직급 | 1/3/6 |
| 양식 | 6종 |
| 결재 문서 | 6건 (completed/in_progress/rejected/draft/withdrawn/긴급) |
| 게시판/게시글/댓글 | 3/5/4 |
| 공지사항/회의실/일정/근태 | 3/3/4/5 |

---

## 기술지원

| 서비스 | 내용 |
|---|---|
| **셀프 설치** | GitHub에서 직접 — 무료 |
| **설치 대행** | 사내 서버 세팅 + 초기 설정 + 교육 |
| **기술지원 계약** | 월간 유지보수 + 업데이트 + 장애 대응 |
| **커스터마이징** | 양식/워크플로우 맞춤 개발 |

문의: [GitHub Issues](https://github.com/sapinfo/rigel/issues)

---

## 라이선스

MIT License
