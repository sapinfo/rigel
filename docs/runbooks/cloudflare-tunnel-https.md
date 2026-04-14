# Cloudflare Tunnel HTTPS 구성 Runbook

> 동적 IP/NAT 뒤 서버에 **포트 개방 없이** HTTPS로 서비스를 공개하는 절차. Cloudflare Tunnel(cloudflared) + CF 엣지의 자동 SSL 사용. Rigel 프로덕션 배포에서 실제 사용된 구성 (2026-04-14).

## 왜 CF Tunnel 인가

| 항목 | CF Tunnel | nginx/Caddy + Let's Encrypt |
|---|---|---|
| 공인 IP 필요 | ❌ 불필요 (아웃바운드만) | ✅ 필요 (A 레코드 대상) |
| 포트포워딩 | ❌ 불필요 | ✅ 80/443 개방 |
| SSL 인증서 관리 | CF 자동 | certbot 자동 갱신 필요 |
| DDoS/WAF | CF 무료 플랜 기본 포함 | 별도 구축 |
| 추가 비용 | 무료 (도메인만 있으면) | 무료 (LE) + VPS 공인 IP |
| 설정 복잡도 | ★ (명령 몇 개) | ★★★ (reverse proxy + certbot) |

**동적 IP, 가정/사무실 회선, 공유기 뒤 서버 = CF Tunnel 강력 권장**.

## 전제

| 항목 | 값 |
|---|---|
| 도메인 | Cloudflare에서 구매 또는 Cloudflare 네임서버로 이전 (DNS Zone이 CF에 있어야 함) |
| 서버 OS | Ubuntu 24.04 (다른 Linux도 호환) |
| 실행 중 서비스 | 서버 내부 포트 (예: `localhost:3000`, `localhost:8000`) |
| sudo 권한 | 설치 및 systemd 등록용 |

## 구성 절차

### 1단계: cloudflared 설치

```bash
curl -L --output /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
cloudflared --version    # v2026.x.x 이상
```

> `apt install cloudflared`는 구버전 가능성 — 공식 `.deb` 권장.

### 2단계: Cloudflare 계정 인증

```bash
cloudflared tunnel login
```

- 콘솔에 URL 출력 → **브라우저에 복붙** → CF 로그인 → 대상 도메인(Zone) 선택 → Authorize
- `~/.cloudflared/cert.pem` 생성됨 (이후 Tunnel/DNS 명령의 자격증명)

### 3단계: 터널 생성

```bash
cloudflared tunnel create <터널명>
# 예: cloudflared tunnel create rigel-prod
```

출력에서 **UUID** 메모. `~/.cloudflared/<UUID>.json` 파일 생성됨.

```bash
cloudflared tunnel list    # 확인
```

### 4단계: 라우팅 설정 (`config.yml`)

```bash
cat > ~/.cloudflared/config.yml <<'EOF'
tunnel: <UUID>
credentials-file: /home/<USER>/.cloudflared/<UUID>.json

ingress:
  # 예시: apex + app + api
  - hostname: example.com
    service: http://localhost:3000
  - hostname: app.example.com
    service: http://localhost:3000
  - hostname: api.example.com
    service: http://localhost:8000

  # 매칭 안 되는 요청은 404
  - service: http_status:404
EOF

cloudflared tunnel ingress validate    # "OK" 확인
```

### 5단계: DNS 라우트 등록 (호스트별)

```bash
cloudflared tunnel route dns <터널명> example.com
cloudflared tunnel route dns <터널명> app.example.com
cloudflared tunnel route dns <터널명> api.example.com
```

각 명령이 CF API를 호출해 **자동으로 CNAME 레코드 생성**. CF 대시보드 > DNS에서 확인 가능:

| Name | Content | Proxy |
|---|---|---|
| example.com | `<UUID>.cfargotunnel.com` | Proxied |
| app | `<UUID>.cfargotunnel.com` | Proxied |
| api | `<UUID>.cfargotunnel.com` | Proxied |

> apex(`example.com`)는 CF의 **CNAME flattening** 덕에 동작. 다른 DNS 제공자에선 불가능.

### 6단계: systemd 서비스 등록

```bash
# 설정을 /etc/cloudflared/로 복사 (root 실행 시 홈디렉터리 접근 불가)
sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/
sudo cp ~/.cloudflared/<UUID>.json /etc/cloudflared/

# /etc/cloudflared/config.yml의 credentials-file 경로도 /etc/cloudflared/로 수정
sudo sed -i 's|credentials-file:.*|credentials-file: /etc/cloudflared/<UUID>.json|' /etc/cloudflared/config.yml

# 서비스 설치
sudo cloudflared service install

# 상태 확인
sudo systemctl status cloudflared --no-pager | head -10
```

**정상 상태**: `active (running)` + `Registered tunnel connection ... protocol=quic` 로그.

### 7단계: 검증

```bash
# 서버 내부에서
curl -sI https://example.com      | head -3
curl -sI https://app.example.com  | head -3
curl -sI https://api.example.com  | head -3
# 모두 HTTP/2 200 또는 서비스별 기대 응답
```

외부(다른 컴퓨터)에서도 같은 URL로 접속 확인. CF 엣지에서 자동 SSL 붙음.

## 운영

### 설정 변경 후 반영

```bash
# config.yml 수정 후
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml    # (user ↔ system)
sudo systemctl restart cloudflared
```

### 호스트명 추가

```bash
# 1. /etc/cloudflared/config.yml 의 ingress 에 추가
# 2. DNS 등록
cloudflared tunnel route dns <터널명> new.example.com
# 3. 재시작
sudo systemctl restart cloudflared
```

### 호스트명 제거

CF 대시보드 > DNS 에서 해당 레코드 수동 삭제 + config.yml에서 제거 + restart.

### 로그 확인

```bash
sudo journalctl -u cloudflared -f
```

### 상태 및 메트릭

```bash
sudo systemctl status cloudflared
curl http://127.0.0.1:20241/metrics    # Prometheus 호환
```

### 업그레이드

```bash
# 이전 방식과 동일하게 .deb 재설치
curl -L --output /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
sudo systemctl restart cloudflared
```

## 트러블슈팅

### Q1. `sudo cloudflared service install` 이 "Cannot determine default configuration path" 오류

- **원인**: sudo 환경에서 `~/.cloudflared/`가 root의 홈디렉터리로 바뀌어 config 없음
- **해결**: config.yml과 credentials JSON을 `/etc/cloudflared/` 로 먼저 복사한 뒤 install

### Q2. `sudo tee /etc/cloudflared/config.yml <<EOF ... EOF` 에서 "Sorry, try again"

- **원인**: expect 기반 sudo 자동화에서 최초 sudo 세션 미형성, heredoc 끝나기 전 비번 프롬프트
- **해결**: `sudo -v` 로 세션 먼저 priming → 이후 sudo 명령은 cached
  ```bash
  sudo -v
  sudo tee /etc/cloudflared/config.yml > /dev/null <<'EOF'
  ...
  EOF
  ```

### Q3. 내부 DNS가 apex를 못 찾음 (서브도메인은 정상)

- **원인**: 로컬 네트워크의 DNS 서버(공유기 Pi-hole 등)가 apex 설정 **이전**에 조회한 NXDOMAIN을 캐시
- **증상**: `dig app.example.com @1.1.1.1` 은 OK, `dig example.com` (로컬 리졸버) 은 빈 응답
- **해결 1**: 로컬 DNS 서버 재부팅 또는 캐시 flush
- **해결 2**: 클라이언트 DNS를 CF(`1.1.1.1`)로 전환
  ```bash
  # macOS
  sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  ```
- **해결 3**: TTL 만료까지 대기 (보통 5분~1시간)

### Q4. 터널은 active인데 `curl https://example.com` 이 404

- **원인**: `config.yml` 의 `ingress` 에 해당 hostname이 없어 `http_status:404` 규칙으로 떨어짐
- **해결**: config.yml에 hostname 추가 + restart. `cloudflared tunnel ingress validate` 로 사전 검증

### Q5. 재부팅 후 터널이 안 올라옴

- **원인**: systemd 서비스 enable 안 됨
- **해결**:
  ```bash
  sudo systemctl enable cloudflared
  sudo systemctl is-enabled cloudflared    # enabled
  ```

### Q6. CF 대시보드에 Tunnel 레코드가 안 보임

- **원인**: `cloudflared tunnel route dns` 가 실패했거나 다른 Zone에 인증됨
- **해결**: `cloudflared tunnel login` 다시 실행해 올바른 Zone 선택, `cert.pem` 교체 후 route 재등록

### Q7. Rigel 앱 같이 PUBLIC_* 빌드타임 env 쓰는 경우

- **원인**: SvelteKit `$env/static/public`은 **빌드 시점**에 JS 번들에 baked. runtime 환경만 바꿔도 브라우저 번들 안 바뀜
- **해결**: `.env` 의 `PUBLIC_SUPABASE_URL` 등을 도메인으로 변경 후 **컨테이너 재빌드** 필수
  ```bash
  podman-compose up -d --build
  ```

## 보안 고려사항

| 레이어 | 기본 제공 | 추가 권장 |
|---|---|---|
| TLS 인증서 | CF 자동 Universal SSL | Full (strict) 모드 원본 인증서 설정 |
| DDoS | CF 기본 보호 | 무료 플랜에도 포함 |
| WAF | 기본 OWASP 룰 | Managed Rules 구독 (유료) 또는 Custom Rules (무료 5건) |
| Bot 제어 | 기본 수준 | Turnstile(CAPTCHA) 무료 추가 |
| 내부망 차단 | - | `iptables` 로 8000/3000 LAN만 허용 (Tunnel은 localhost로 접근하므로 영향 없음) |
| API 남용 | Kong apikey (Supabase) | CF Rate Limiting Rules (유료) / Zero Trust Access (무료 50 user) |

### Rigel 환경에서 권장 세팅

- **Rate Limit**: `https://app.example.com/signup` 에 분당 5회 제한 (CF Rules > Rate Limiting)
- **Turnstile**: signup 폼에 clientside + server-side 검증 추가
- **Zero Trust Access**: `api.example.com`·`studio.example.com` 등 관리자 엔드포인트는 이메일 OTP 제한

## 파일·디렉터리 레퍼런스

| 경로 | 용도 |
|---|---|
| `~/.cloudflared/cert.pem` | CF 계정 인증 (tunnel/route 명령에 필요) |
| `~/.cloudflared/<UUID>.json` | 터널별 자격증명 |
| `~/.cloudflared/config.yml` | user 스코프 설정 (CLI 테스트용) |
| `/etc/cloudflared/config.yml` | systemd 서비스가 읽는 설정 (**실제 운영값**) |
| `/etc/cloudflared/<UUID>.json` | systemd용 자격증명 |
| `/etc/systemd/system/cloudflared.service` | systemd unit |

## 설치 완료 체크리스트

- [ ] `cloudflared --version` 2026.x 이상
- [ ] `~/.cloudflared/cert.pem` 존재
- [ ] `cloudflared tunnel list` 에 터널 표시
- [ ] `/etc/cloudflared/config.yml`, `<UUID>.json` 존재 (root 소유)
- [ ] `cloudflared tunnel ingress validate` OK
- [ ] `sudo systemctl is-enabled cloudflared` = enabled
- [ ] `sudo systemctl is-active cloudflared` = active
- [ ] `journalctl -u cloudflared -n 5` 에 `Registered tunnel connection` 4개 (기본 CF 엣지 4개 연결)
- [ ] CF 대시보드 DNS 에 해당 호스트 CNAME (Proxied) 존재
- [ ] 외부 IP에서 `curl -sI https://<host>` 200 응답

## 참고

- Cloudflare Tunnel 공식 문서: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- 관리 UI: `https://one.dash.cloudflare.com/` > Networks > Tunnels
- 2026-04-14 Rigel 프로덕션 실제 구성 기록: [rigel-supabase-integration.md](./rigel-supabase-integration.md)
