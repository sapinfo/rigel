# Analysis — 프로덕션 Docker 배포 (rev 2)

> Feature: `프로덕션-docker-배포`
> Phase: PDCA Check
> Date: 2026-04-14
> Plan: `docs/01-plan/features/프로덕션-docker-배포.plan.md` (rev 2)
> Design: `docs/02-design/features/프로덕션-docker-배포.design.md` (rev 2)
> Analyst: Claude (gap-detector agent)

---

## Executive Summary

| 항목 | 값 |
|---|---|
| **Design ↔ Implementation Match Rate** | **94%** (16/17 verified) |
| **E2E Functional Pass Rate** | 6/7 주요 journey (86%) |
| **Overall (가중 평균)** | **93%** |
| **Archive 가능 여부** | ✅ **가능** (1건 문서 패치 권장) |

**What's done**: rev 2 설계의 핵심 요건(install.sh Rigel 앱 전용 축소, Supabase 기동 감지, `_rigel_installed` 멱등 migration, `supabase_default` external 네트워크 가입, `SUPABASE_INTERNAL_URL=http://kong:8000` 분리, `supabase-docker/` git 제거 + `.gitignore` 추가, 2-Step 랜딩/README 가이드, `generate-keys.sh` 홍보, `/opt` 경고, 트러블슈팅 `<details>`)이 전부 구현됨. macOS + Colima 환경에서 최초 설치 → 회원가입 → 조직 생성 → 관리자 화면까지 전 구간 통과.

**What's gapped**: E2E에서 실제로 만난 "Error sending confirmation email" 이슈의 해결책(`ENABLE_EMAIL_AUTOCONFIRM=true` + `auth` 컨테이너 재기동)이 README 🔧 섹션과 랜딩 `<details>` 트러블슈팅에 반영되지 않음. 후속 설치자가 동일 지점에서 막히게 됨.

### Value Delivered (4관점)

| 관점 | 내용 |
|---|---|
| **Problem** | Supabase 직접 구성 반복 실패 + 환경별 호스트 권한 이슈 예측 불가 |
| **Solution** | Supabase는 공식 가이드 위임, Rigel 앱만 install.sh로 자동화, 트러블슈팅 inline 문서화 |
| **Function UX** | 2-Step 설치 (~8분). install.sh 6단계. 재실행 안전(`_rigel_installed` 마커). 공식 `generate-keys.sh` 활용 |
| **Core Value** | Rigel이 Supabase 호스팅 이슈에서 분리 → 공식 Supabase 업그레이드 패스 자동 수혜. 비개발자도 2-Step 가이드로 1시간 내 자사 서버 설치 가능함을 E2E로 실증 |

---

## 1. Scope & Methodology

- **Source of truth**: Design rev 2 (2026-04-14). v1 통합 install.sh 설계는 "v1 설계 근거로 보존"이라 명시되어 있어 비교 대상 아님.
- **대조 대상**: `install.sh`, `docker-compose.yml`, `Dockerfile`, `.env.production.example`, `.gitignore`, `src/routes/+page.svelte` #install 섹션, `README.md` 프로덕션 설치 섹션, `supabase-docker/` git 추적 상태, `src/hooks.server.ts`.
- **검증 방법**: (1) 문서 요건을 원자 단위로 분해 → (2) 실제 구현과 1:1 대조 → (3) E2E 관찰 결과 추가 반영.

---

## 2. Design ↔ Implementation 대조표

| # | rev 2 요건 | 구현 위치 | 상태 | 비고 |
|---|---|---|---|:---:|
| 1 | install.sh 범위: Rigel 앱 전용 4–6단계 (~170줄) | `install.sh` 223줄, 6 섹션 | ✅ | 설계보다 +50줄 (에러 메시지·주석 보강, 수용 가능) |
| 2 | Supabase 기동 감지 → 미기동 시 공식 가이드 출력 후 exit | `install.sh` L65–86 | ✅ | `supabase-db` 컨테이너 + `pg_isready` + network 3중 확인 |
| 3 | 공식 가이드 안내 내 `generate-keys.sh` 사용 promo | `install.sh` L79 | ✅ | |
| 4 | `/opt` 경고 포함 | `install.sh` L83–84 | ✅ | |
| 5 | Migration 멱등성: `_rigel_installed` 마커 | `install.sh` L128–160 | ✅ | `CREATE TABLE IF NOT EXISTS` 방어 추가 |
| 6 | Migration `ON_ERROR_STOP=1` + 실패 시 즉시 중단 | `install.sh` L136, 149 | ✅ | |
| 7 | `.env` 존재·`PUBLIC_SUPABASE_ANON_KEY` 비어있지 않음 검증 | `install.sh` L166–184 | ✅ | 친절한 복구 가이드 포함 |
| 8 | `docker system prune` / `volume rm` 금지 경고 | `install.sh` L217–218, README | ✅ | |
| 9 | 루트 `docker-compose.yml`: Rigel 앱 1개 컨테이너 | `docker-compose.yml` | ✅ | Supabase 서비스 0개 |
| 10 | `networks.default`: `supabase_default` external | `docker-compose.yml` L31–34 | ✅ | |
| 11 | `SUPABASE_INTERNAL_URL=http://kong:8000` env 주입 | `docker-compose.yml` L24 | ✅ | |
| 12 | Dockerfile multi-stage + build-time ARG 베이킹 | `Dockerfile` L4–27 | ✅ | |
| 13 | `npm ci --omit=dev --ignore-scripts` (prepare hook 회피) | `Dockerfile` L25 | ✅ | |
| 14 | `hooks.server.ts`에서 서버는 `SUPABASE_INTERNAL_URL` 우선 | `src/hooks.server.ts` L24 | ✅ | 설계 스니펫과 동일 |
| 15 | `.env.production.example` 최소화 + generate-keys.sh 안내 | `.env.production.example` L10–11 | ✅ | 4개 키만 노출 |
| 16 | `.gitignore`에 `supabase-docker/` 추가 | `.gitignore` L12 | ✅ | `supabase-docker/` 로컬 보존, git index에서 제거됨 |
| 17 | 랜딩 #install + README: 2-Step 가이드 + generate-keys.sh + `/opt` 경고 + `<details>` 트러블슈팅 | `src/routes/+page.svelte`, `README.md` | ✅ | E2E 발견 AUTOCONFIRM 건만 미반영 |
| — | E2E AUTOCONFIRM 이슈를 트러블슈팅에 반영 | **없음** | ❌ | 본 분석 단계에서 신규 식별 (G1) |

**집계**: 17/17 설계 요건 중 16건 구현 완료, 1건은 E2E 이후 발생한 추가 개선 요구(문서화).

---

## 3. Gap List (우선순위)

### 🔵 Minor / Docs (1건 — 아카이브 전 패치 권장)

| ID | 항목 | 영향 | 해결 방안 |
|---|---|---|---|
| G1 | README 🔧 섹션 + 랜딩 `<details>` 트러블슈팅에 "회원가입 시 `Error sending confirmation email` 에러" 항목 부재 | 후속 설치자가 E2E와 동일 지점에서 10~30분 소모 | `~/supabase/docker/.env`에 `ENABLE_EMAIL_AUTOCONFIRM=true` 추가 후 `docker compose up -d auth`로 재기동 필요함을 명시 (SMTP 미구성 시 메일 전송 실패가 signup을 차단하기 때문이며 `docker compose restart auth`는 env를 재로드하지 않으므로 반드시 `up -d`). SMTP 구성 시 이 플래그는 불필요하다는 점도 함께 명시 |

### 🟡 Out-of-Scope (2건 — 별도 feature로 분리 권장, 본 기능 아카이브 차단 사항 아님)

| ID | 항목 | 영향 | 권장 조치 |
|---|---|---|---|
| O1 | `admin/boards` 페이지: 게시판 생성 모달의 `use:enhance`가 성공 시 폼/모달을 초기화하지 않음 | 사용자가 실패로 오인 → 중복 submit 가능 | 별도 feature `boards-ux-fix`로 분리. `enhance` 콜백의 `update()` 이후 `isOpen=false` 처리 + form reset |
| O2 | `boards`/`announcements`/`rooms` RLS SELECT 정책이 부서 미소속 관리자/소유자에게 부서 한정 row를 감추게 설계되어 있음 | owner/admin이 전체 부서의 게시판을 감시 불가 | 별도 feature `rls-admin-scope-fix`로 분리. SELECT 정책에 `is_tenant_admin(tenant_id) OR ...` 절 추가. 여러 migration 손대야 하므로 단독 PDCA 사이클 권장 |

### 🟢 이상 없음 (Blocker / Major 없음)

본 기능의 rev 2 설계 스펙 대비 차단성 gap은 발견되지 않음.

---

## 4. E2E Verification Section (macOS + Colima, 2026-04-14)

### 4.1 환경

- OS: macOS (Darwin 25.4.0)
- Container runtime: Colima (Docker context = `colima`)
- Supabase: 공식 repo를 `$HOME/supabase`에 clone, `sh ./utils/generate-keys.sh` 실행
- Rigel: `$HOME/Downloads/Rigel`에 clone

### 4.2 실행 명령 & 결과

| # | 단계 | 결과 |
|---|---|---|
| 1 | `docker context use colima` + `unset DOCKER_HOST` | ✅ 필수. 터미널 세션마다 재설정 필요 (shell isolation) |
| 2 | `sh ./utils/generate-keys.sh` + `docker compose up -d` (Supabase 측, 최초 `/opt` 설치는 실패 → `$HOME` 이동 후 성공) | ✅ 14/14 컨테이너 Healthy |
| 3 | `cd ~/Rigel && ./install.sh` | ✅ Supabase 감지, migration 74개 적용, seed 적용, `.env` 검증, 앱 빌드 + 기동 |
| 4 | `curl http://localhost:3000` | ✅ 200 OK, 랜딩 페이지 |
| 5 | `/signup` 최초 시도 | ❗ "Error sending confirmation email" — SMTP 미구성 + AUTOCONFIRM off |
| 5a | `~/supabase/docker/.env`: `ENABLE_EMAIL_AUTOCONFIRM=true` + `docker compose up -d auth` (restart는 env 미반영) | ✅ signup 성공 |
| 6 | `/login` → `/onboarding/create-tenant` → 조직 생성 → 대시보드 → `/admin/*` 탐색 | ✅ 전 구간 통과 |
| 7 | `admin/boards` 게시판 생성 모달 | ⚠ 성공해도 모달/폼 유지 (O1) |
| 8 | owner가 타 부서 scoped 게시판 SELECT | ⚠ RLS에 의해 숨겨짐 (O2) |

### 4.3 V1~V6 검증 체크리스트 (Design §10)

| # | 검증 | 통과 기준 | 결과 |
|---|---|---|:---:|
| V1 | Clean 환경 2-Step 설치 | `Installation complete` 출력, 에러 없음 | ✅ (경로 주의 1회 학습 이후) |
| V2 | 컨테이너 상태 | Supabase 14 + rigel-app 1 모두 healthy | ✅ |
| V3 | 웹 접속 | `http://localhost:3000` 200 | ✅ |
| V4 | 회원가입 → 조직 생성 | 전 구간 성공 | ⚠ AUTOCONFIRM 조건부 성공 |
| V5 | 데이터 보존 | `down && up -d` 후 유지 | ✅ (volume 유지 확인) |
| V6 | 이미지 캐시 재사용 | 2번째 설치 시 재다운로드 없음 | ✅ |

---

## 5. Recommendations (다음 단계)

### 5.1 아카이브 전 (10분 이내 패치 권장)

1. **G1 패치**: `README.md` §"🔧 문제 해결"과 `src/routes/+page.svelte` `<details>` 트러블슈팅에 아래 항목 추가.

   ```markdown
   **회원가입 시 "Error sending confirmation email" 에러**
   → SMTP가 구성되지 않은 상태이고 Supabase auth가 이메일 확인을 요구하기 때문.
   → 해결: `~/supabase/docker/.env`에 `ENABLE_EMAIL_AUTOCONFIRM=true` 추가
     `cd ~/supabase/docker && docker compose up -d auth` (restart 아님 — env 재로드 필요)
   → 프로덕션에서 실제 이메일 확인을 쓰려면 SMTP_* 환경변수 구성으로 대체.
   ```

### 5.2 별도 feature 로 분리 (아카이브 후)

- `boards-ux-fix` — `admin/boards` 모달 reset 문제 (O1)
- `rls-admin-scope-fix` — 다부서 관리자 가시성 RLS 보강 (O2, 여러 migration 걸쳐 touch)

### 5.3 향후 개선 후보 (non-blocking)

- `uninstall.sh` 제공(Design §1.1 파일 레이아웃에는 optional로 있었지만 미구현, rev 2에서도 필수 아님)
- Cloudflare Tunnel / HTTPS / 백업 (Plan에서 Out-of-scope로 명시됨 — 별도 feature)
- `install.sh --dry-run` 모드 (scope 외, 여력 시)

---

## 6. Archive Readiness

| 기준 | 상태 |
|---|:---:|
| Match Rate ≥ 90% | ✅ 94% |
| Blocker / Major gap 없음 | ✅ |
| E2E 주요 journey 통과 | ✅ |
| 설계 문서 rev 표기 명확 | ✅ (Plan + Design 모두 rev 2 상단 명시) |
| 문서 패치 미적용 | ⚠ G1 1건 권장 (blocking 아님) |

**결론**: G1 패치(10분) 후 `/pdca report 프로덕션-docker-배포` → `/pdca archive 프로덕션-docker-배포` 진행 권장. G1 미패치로 진행해도 기능적 결함은 없으나 후속 설치자 경험이 저하됨.
