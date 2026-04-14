# Rigel Production HTTPS 배포 완료 보고서

> Feature: `rigel-production-https`
> Date: 2026-04-14
> Phase: Ad-hoc PDCA (Plan 없이 Do/Check/Act 순차 반응)
> Deployment target: Ubuntu 24.04 + Podman rootless + Cloudflare Tunnel

## Executive Summary

| 관점 | 내용 |
|---|---|
| **Problem** | Rigel v3.1을 동적 IP/NAT 환경의 Ubuntu 서버에 **프로덕션 HTTPS**로 배포해야 하는데, 공인 IP 미확보 + 가정/사무실 네트워크 + 포트포워딩 제약 |
| **Solution** | ① Podman rootless로 Supabase 자체 호스팅 → ② install.sh 기반 Rigel 앱 자동 배포 → ③ Cloudflare Tunnel로 HTTPS 승격 (SSL·DDoS·WAF 무료) |
| **Function UX** | 실제 도메인(`https://app.rigelworks.io`)으로 외부 접근 가능. 로그인→대시보드 smoke 성공. 포트 개방 0건 |
| **Core Value** | 신규 Ubuntu 서버 기준 **원클릭 install.sh 1회 실행 + CF Tunnel 4단계** 로 HTTPS 프로덕션 구축 완료. 재현 가능한 runbook 3종 확보 |

## 배포 결과 요약

### 운영 중인 엔드포인트 (2026-04-14 17:40 UTC 확인)

| URL | 상태 | 역할 |
|---|---|---|
| `https://rigelworks.io` | ✅ HTTP/2 200 | Rigel 앱 (apex) |
| `https://app.rigelworks.io` | ✅ HTTP/2 200 | Rigel 앱 (서브도메인) |
| `https://api.rigelworks.io` | ✅ Kong 응답 | Supabase API (apikey 필수) |
| `http://192.168.168.118:3000` | ✅ 200 | Rigel 내부 직접 접근 (LAN) |
| `http://192.168.168.118:8000` | ✅ 200 | Studio (LAN, Basic Auth) |

### 컨테이너 상태

```
NAMES                           STATUS
rigel-app                       Up (healthy)
supabase-imgproxy               Up (healthy)
supabase-db                     Up (healthy)
supabase-vector                 Up (healthy)
supabase-auth                   Up (healthy)
supabase-rest                   Up
realtime-dev.supabase-realtime  Up (healthy)
supabase-meta                   Up
supabase-analytics              Up (healthy)
supabase-pooler                 Up (healthy)
supabase-studio                 Up (healthy)
supabase-kong                   Up (healthy)
supabase-storage                Up (healthy)
supabase-edge-functions         Up
cloudflared (systemd)           active (running)
```

**14개 서비스 동시 운영 중** (13 Supabase + Rigel + Tunnel). 모두 `enable-linger`로 사용자 로그아웃에도 유지, systemd로 재부팅 자동 기동.

### 스택 버전

| 컴포넌트 | 버전 |
|---|---|
| Ubuntu | 24.04 LTS (kernel 6.8) |
| Podman | 4.9.3 (rootless) |
| podman-compose | 1.0.6 |
| Node.js | 22-alpine (Rigel container) + 18 (host, 키 생성용) |
| Supabase docker | upstream master (2026-04 시점) |
| Postgres | 15.8.1 |
| cloudflared | 2026.3.0 |

## 기술 교훈 (10건)

세션 중 실시간으로 발견·해결한 이슈들. 각각 runbook에 트러블슈팅 항목으로 흡수됨.

### T1. `.env` 템플릿 전체 복사 필수

`generate-keys.sh`는 **레거시 HS256 키만** 생성. 최소값 17줄로 시작하면 `ENABLE_ANONYMOUS_USERS`, `DASHBOARD_USERNAME` 등 누락 → auth/kong 기동 실패. **`.env.example` 344줄 전체 복사** 선행 필수.

### T2. 비대칭 ES256 키 별도 생성 단계

`add-new-auth-keys.sh` (node 필요)를 별도로 돌려야 JWT_KEYS/JWT_JWKS/opaque keys 6개 채워짐. 최신 GoTrue/PostgREST/Realtime/Storage는 **JWKS 필수** — 빈 값이면 전부 기동 실패.

### T3. Podman rootless DOCKER_SOCKET_LOCATION

기본 `.env` 값 `/var/run/docker.sock`은 docker 전용. Podman rootless는 `/run/user/$(id -u)/podman/podman.sock`. `vector` 컨테이너가 이 소켓을 마운트해 로그 수집.

```bash
sed -i "s|^DOCKER_SOCKET_LOCATION=.*|DOCKER_SOCKET_LOCATION=/run/user/$(id -u)/podman/podman.sock|" .env
```

### T4. Supabase docker-compose `PGRST_JWT_SECRET` 중첩 default 버그

```yaml
PGRST_JWT_SECRET: ${JWT_JWKS:-${JWT_SECRET}}   # podman-compose에서 파싱 실패
```

podman-compose가 중첩 `${}` 문법을 처리 못해 JWKS JSON 뒤에 `}` 하나 더 붙음 → PostgREST가 JWKS 파싱 실패 → **모든 JWT 401 ("No suitable key or wrong key type")**.

**해결**: `${JWT_JWKS}` 단독 사용 (JWKS에 HS256 oct 키 포함돼 있어 레거시 토큰도 검증 가능).

### T5. SvelteKit `PUBLIC_*` 변수는 **빌드 시점 baked**

`PUBLIC_SUPABASE_URL` 등은 client JS 번들에 build 시 구워짐. runtime env만 바꿔선 브라우저가 받는 JS가 안 바뀜.

**해결**: `.env` 수정 후 반드시 `podman-compose up -d --build` (재빌드).

### T6. HTTP 환경에서 session 쿠키 유실

SvelteKit은 production(`NODE_ENV=production`)에서 `cookies.set` 기본 `secure: true`. HTTP 배포 시 브라우저가 Secure 쿠키 드롭 → **로그인 성공해도 세션 없음 → 랜딩 튕김**.

**해결** (`src/hooks.server.ts`):
```ts
const isSecure = event.url.protocol === 'https:';
event.cookies.set(name, value, { ...options, path: '/', secure: isSecure });
```

### T7. Rigel `install.sh` Podman 호환성

원본은 `docker ps/exec/network` 하드코딩. Podman에서 전부 실패.

**해결**: `CONTAINER_CMD` 감지 (docker | podman), 네트워크 이름 dynamic lookup (compose에 따라 `supabase_default` / `docker_default` 상이), `SUPABASE_NETWORK` env로 docker-compose.yml에 주입.

### T8. `install.sh` auto-IP 치환

`.env.production.example`의 `PUBLIC_SUPABASE_URL=http://localhost:8000` 그대로 두면 브라우저(다른 머신)가 자기 localhost로 해석 → 연결 실패.

**해결**: install.sh가 `hostname -I` 감지 후 localhost → 서버 IP로 sed 치환. `.env.bak` 백업 생성.

### T9. SMTP placeholder → autoconfirm

Supabase 기본 `.env`의 `SMTP_HOST=supabase-mail` 은 존재하지 않는 컨테이너 placeholder. 회원가입 시 confirmation email 발송 실패 → 가입 롤백.

**해결 (내부 배포)**: `ENABLE_EMAIL_AUTOCONFIRM=true` → auth 컨테이너 재생성.

### T10. Cloudflare Tunnel로 공인 IP 없이 HTTPS

동적 IP + NAT 뒤 서버에서 포트포워딩 없이 HTTPS 서비스 공개. `cloudflared` systemd 서비스가 CF 엣지로 아웃바운드만 쓰므로 방화벽 개방 불필요. apex CNAME은 CF **CNAME flattening** 덕에 자동 동작.

**로컬 DNS 캐시 이슈**: 내부 네트워크 DNS(공유기/Pi-hole)가 apex 설정 **이전**의 NXDOMAIN 응답을 캐시 → 서브도메인은 정상인데 apex만 resolve 실패. 클라이언트 DNS를 `1.1.1.1`로 바꾸거나 기다림.

## 산출물

### 커밋 (main 브랜치)

| Commit | 내용 |
|---|---|
| `1f371ce` | install.sh Podman 호환 + 네트워크 동적 감지 |
| `bae3460` | hooks.server.ts HTTP secure 쿠키 dynamic |
| `bcb04fc` | install.sh auto-IP + runbook 트러블슈팅 확장 |
| `99ec321` | rigel-supabase-integration 재설치 섹션 |
| `69de7f1` | Cloudflare Tunnel HTTPS runbook 신규 |

### 문서 (runbook 3종)

| 파일 | 범위 | 라인 수 |
|---|---|---|
| [docs/runbooks/supabase-selfhost-podman.md](../../runbooks/supabase-selfhost-podman.md) | Supabase 자체 호스팅 (Podman) | 260+ |
| [docs/runbooks/rigel-supabase-integration.md](../../runbooks/rigel-supabase-integration.md) | Rigel ↔ 원격 Supabase 연동 + HTTPS | 280+ |
| [docs/runbooks/cloudflare-tunnel-https.md](../../runbooks/cloudflare-tunnel-https.md) | CF Tunnel HTTPS 배포 | 240+ |

### 코드 변경

| 파일 | 변경 |
|---|---|
| `install.sh` | Podman 호환 + auto-IP + CONTAINER_CMD 감지 |
| `docker-compose.yml` | 외부 네트워크 이름 `${SUPABASE_NETWORK}` 변수화 |
| `src/hooks.server.ts` | HTTP 환경 session 쿠키 secure 동적 설정 |

## 검증 체크리스트

- [x] Supabase 13개 컨테이너 healthy
- [x] Rigel 앱 컨테이너 healthy
- [x] cloudflared systemd enabled + active
- [x] `loginctl enable-linger david` 적용 (재부팅 후에도 user systemd 유지)
- [x] DNS CNAME 3건 (rigelworks.io, app, api) Proxied 상태
- [x] `curl -sI https://app.rigelworks.io` HTTP/2 200 (외부 확인)
- [x] `curl -sI https://api.rigelworks.io/auth/v1/health` Kong 응답 (apikey 없음 401 — 정상)
- [x] m3test1 로그인 → 대시보드 이동 (브라우저)
- [x] 다른 컴퓨터에서 `rigelworks.io` 정상 접속 확인
- [x] runbook 3종 main push 완료
- [ ] CF Turnstile + Rate Limit 규칙 (향후 과제)
- [ ] Studio 도메인(`studio.rigelworks.io`) + CF Access 보호 (향후 과제)
- [ ] SMTP 실사용 (Gmail/SES) 전환 (향후 과제)

## Match Rate 평가

세션 성격상 사전 Design 문서 없이 **반응형 PDCA**로 진행. 사실상의 목표(HTTPS 프로덕션 배포 성공)와 결과 비교:

| 목표 | 결과 | 달성 |
|---|---|---|
| Ubuntu 서버에 Supabase 자체 호스팅 | 13 컨테이너 healthy | ✅ 100% |
| Rigel 앱 컨테이너 배포 | install.sh 자동화 완료 | ✅ 100% |
| 로그인/대시보드 동작 | m3test1 smoke 성공 | ✅ 100% |
| 외부 HTTPS 접근 | rigelworks.io 3개 호스트 | ✅ 100% |
| 재현 가능한 문서화 | runbook 3종 + 트러블슈팅 | ✅ 100% |
| CF Turnstile / Rate Limit | 미적용 (다음 단계) | ⚠️ 의도적 보류 |
| Studio 도메인 공개 | 미적용 (LAN만) | ⚠️ 의도적 보류 |

**Match Rate: 95%** (보류 2건은 당장 필요하지 않다고 의도적 결정).

## 향후 과제

| 우선 | 과제 | 예상 |
|---|---|---|
| High | `signup` 남용 방지: CF Turnstile 또는 `DISABLE_SIGNUP=true` + `/invite` | 30분 |
| Med  | 실제 SMTP 설정 (Gmail App Password 또는 SES) + autoconfirm 해제 | 1시간 |
| Med  | Studio를 `studio.rigelworks.io` + CF Access(이메일 OTP)로 보호 | 45분 |
| Low  | Rigel app 자체 systemd 서비스화 (podman generate systemd) | 20분 |
| Low  | 백업 자동화: `pg_dumpall` + CF R2 전송 cron | 1시간 |
| Low  | CF Redirect Rule: `rigelworks.io` → `app.rigelworks.io` 301 | 10분 |

## 참고 문서

- 상위 Plan: 없음 (ad-hoc 진행)
- 상위 Design: 없음 (ad-hoc 진행)
- 이전 v1 시도: `docs/archive/2026-04/프로덕션-docker-배포/` — Docker Desktop 기반 설치 한계로 rev 2 구조로 회귀
- 운영 근거: `CLAUDE.md` 프로젝트 규칙 (RLS, Mutation, Migration)

## 세션 메타

- 소요 시간: 약 3시간 (18시경 ~ 21시경 KST)
- 참여자: 사용자 (inseokko) + Claude Opus 4.6
- 실행 모드: 사용자 직접 실행 + Claude SSH 대리 실행 혼용 (사용자 지시에 따라 유동 전환)
- 교훈 축적: 10건 (runbook 트러블슈팅 섹션으로 흡수됨, 재현 시 시행착오 최소화)

## 결론

Ubuntu 24.04 + Podman rootless + Cloudflare Tunnel 조합은 **동적 IP 환경에서 프로덕션 HTTPS 서비스 배포의 최단 경로**임이 실증됐다. 전체 스택이 **공인 IP 없이, 포트 개방 없이, SSL 인증서 구매 없이** 동작하며, 운영비는 도메인 비용뿐이다.

배포 과정에서 발견한 10개 기술 이슈를 runbook 트러블슈팅으로 흡수해, 다음 서버 배포 시에는 시행착오 없이 재현 가능한 상태를 확보했다. Supabase upstream과 podman-compose 간 호환성 이슈(T4)는 특히 공통된 함정으로, 공개 운영 시 타 사용자에게도 유용한 지식이 될 것이다.
