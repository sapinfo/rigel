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

## 프로덕션 설치 (Linux 권장)

**구조**: Supabase 공식 셀프호스팅 + Rigel 앱 분리. Supabase를 공식 가이드대로 직접 설치한 뒤 Rigel이 해당 Supabase에 연결합니다.

### 사전 요구

- **Linux** (Ubuntu 24.04+ 권장) 또는 macOS
- **Docker** + Docker Compose — https://docs.docker.com/get-docker/
- **Git**
- 서버 또는 PC (CPU 4코어, RAM 16GB 이상, 디스크 40GB 이상)

> Node.js와 Supabase CLI는 **불필요**합니다. 모두 컨테이너로 실행됩니다.

> ⚠️ **설치 경로 주의**: 반드시 **일반 유저 홈 디렉토리**(`$HOME`)에 설치하세요.
> `/opt`, `/usr/local` 같은 시스템 경로는 **권한 문제로 Supabase 초기화 실패**합니다
> (bind mount된 init 스크립트 read 실패 → `_supabase` DB 생성 안 됨 → analytics 컨테이너 crashloop).
> macOS Docker Desktop은 Settings → Resources → File Sharing에 설치 경로가 포함되어 있어야 합니다
> (기본 `/Users`는 포함).

---

### Step 1. Supabase 공식 셀프호스팅 설치

공식 가이드 그대로 따릅니다: https://supabase.com/docs/guides/self-hosting/docker

```bash
# 공식 저장소 클론 ($HOME 같은 일반 유저 경로에서)
cd ~
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env

# ⚡ 보안 키 자동 생성 (공식 유틸리티, 매우 편리)
sh ./utils/generate-keys.sh

# 기동
docker compose pull
docker compose up -d

# 검증: 모든 컨테이너 Healthy 인지 확인 (약 30~60초 소요)
docker compose ps
```

> 💡 **`generate-keys.sh` 사용 권장**: Supabase 공식 유틸리티가
> `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`,
> `DASHBOARD_PASSWORD` 등 모든 시크릿을 자동 생성해 `.env`에 주입합니다.
> 실행 후 `.env` 내용을 한 번 검토하세요.

> ❌ **기동 이후 비밀번호 변경 금지**: 최초 `docker compose up` 이후
> `POSTGRES_PASSWORD`를 바꾸면 supabase-analytics 컨테이너가 깨집니다.
> 키는 *기동 전에* 최종 확정하세요.

---

### Step 2. Rigel 앱 설치

Supabase가 기동 중인 상태에서 Rigel 소스를 받고 `install.sh`를 실행합니다.
스크립트가 Supabase 기동 확인 → migration + seed 적용 → 앱 빌드/기동을 순차 수행합니다.

```bash
# Rigel 소스 (Supabase 디렉토리와 별도 위치)
cd ~
git clone https://github.com/sapinfo/rigel.git
cd rigel

# .env 생성 + Supabase 연결 정보 입력
cp .env.production.example .env
nano .env
# → PUBLIC_SUPABASE_ANON_KEY에 ~/supabase/docker/.env 의 ANON_KEY 값 붙여넣기

# 설치 실행
./install.sh
```

**.env에 입력할 값**:
- `PUBLIC_SUPABASE_URL` = `http://localhost:8000` (같은 호스트) 또는 서버 IP/도메인
- `PUBLIC_SUPABASE_ANON_KEY` = `~/supabase/docker/.env`의 `ANON_KEY` 값 복사
- `SITE_URL` = 브라우저 접속 주소 (기본 `http://localhost:3000`)

---

### Step 3. 접속

- **Rigel**: `http://서버IP:3000` → 회원가입 → 조직 생성 → 양식 등록
- **Supabase Studio**: `http://서버IP:8000` (아이디 `supabase`, 비번은 `~/supabase/docker/.env`의 `DASHBOARD_PASSWORD`)

---

### 자주 쓰는 명령어

**Rigel 앱** (`cd ~/rigel`):
```bash
docker compose down                       # 중지
docker compose restart                    # 재시작
docker compose logs -f app                # 로그
git pull && docker compose up -d --build  # 업데이트
```

**Supabase** (`cd ~/supabase/docker`):
```bash
docker compose down                       # 중지
docker compose restart                    # 재시작
docker compose logs -f                    # 로그
```

### ⚠ 금지 사항

- ❌ `docker system prune` — 이미지 캐시 전부 삭제됨 (재설치 시 수 GB 재다운로드)
- ❌ `docker volume rm` — **모든 데이터 소실** (복구 불가)

> **재실행 안전**: `docker compose down` 해도 데이터는 volume에 보존됩니다.

### 🔧 문제 해결

**`supabase-analytics` unhealthy / `_supabase` DB 없음 에러**
→ 대부분 **설치 경로 권한 문제**. `/opt` 등 root 소유 경로에 설치한 경우 bind mount된 `volumes/db/*.sql` init 스크립트를 postgres 컨테이너가 읽지 못해 `_supabase` DB가 생성되지 않습니다.
→ **해결**: 전체 디렉토리를 `$HOME` 하위로 이동 → 재기동.

**`POSTGRES_PASSWORD` 변경 후 analytics 깨짐**
→ 최초 기동 이후 비밀번호 변경은 지원 X. 복구: `cd ~/supabase/docker && docker compose down` → `sudo rm -rf volumes/db/data` (데이터 손실!) → `docker compose up -d`.

**macOS bind mount 에러**
→ Docker Desktop → Settings → Resources → File Sharing에 설치 경로 포함되어 있어야 함.

**Rigel 앱 "Supabase not running" 에러**
→ `install.sh`는 `supabase-db` 컨테이너와 `supabase_default` 네트워크가 있어야 동작. `docker compose ps`로 Supabase 기동 먼저 확인.

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
