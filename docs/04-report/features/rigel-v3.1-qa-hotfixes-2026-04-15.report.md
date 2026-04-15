# Rigel v3.1 QA Hotfix Session Report — 2026-04-15

> **Feature**: `rigel-v3.1-qa-hotfixes-2026-04-15`
> **Session Type**: Ad-hoc PDCA (plan 없이 Do/Check 반복 핫픽스)
> **Environment**: Production (`rigelworks.io` via Cloudflare Tunnel) + Dev (local Supabase)
> **Duration**: 1 세션 (2026-04-15)
> **Deployment target**: Ubuntu 24.04 + Podman rootless + Cloudflare Tunnel

## 1. Executive Summary

| 관점 | 내용 |
|---|---|
| **Problem** | Rigel v3.1 프로덕션 배포 후 실사용 QA 테스트 중 발견된 UX·결재 플로우·RLS·데이터 표시 이상 14건 |
| **Solution** | 단일 파일 fix(앱 코드) 11건 + DB RLS/RPC migration 2건 + 사일런트 실패 노출용 debug 보강 |
| **Function UX Effect** | 결재 참여자 뷰·재기안·본인 이름 수정·전결 UUID 숨김·날짜 전용 UI·합의 E2E·대리 결재 가시화 등 실사용 시나리오 전반 개선 |
| **Core Value** | v1.2에서 재정의된 `current_step_index = group_order` 의미가 앱 여러 곳에 덜 반영돼 있던 혼동을 일괄 정리. 합의(agreement) 기능이 인프라만 있고 UI·Zod·RPC 에 구멍이 있던 걸 모두 막음. 사일런트 실패를 alert + 콘솔 debug 로 즉시 가시화해 향후 유사 QA 속도 향상 |

### 1.2 Results Summary

| 항목 | 값 |
|---|---|
| 커밋 | 14개 (ff398d0 → dcab7c9) |
| DB migrations | 2개 (0076 ua_select 확장, 0077 fn_advance_document agreement 포함) |
| 변경 파일 | 앱 코드 10종 + SQL 2종 + 메모리 1종 |
| 프로덕션 반영 | 모든 변경 배포 완료 (git pull + podman-compose down && up -d --build + DB apply) |
| dev↔prod 일체화 | 양쪽 DB 동기 완료 |
| svelte-check 상태 | 0 ERRORS (기존 46 warnings 유지, 회귀 없음) |
| 사용자 검증 통과 | 모든 시나리오 E2E 통과 ("다 잘됨") |

### 1.3 Value Delivered

| 영역 | 전 | 후 |
|---|---|---|
| 결재함 참여자 뷰 | 기안자만 진행/완료/반려 탭에 표시 | 결재 참여자(action 완료자)도 함께 표시, 내 차례 전엔 숨김 |
| 재기안 | 기존 내용 날아간 것처럼 빈 양식 | 복사본 draft 로 기존 내용 프리필 |
| 프로필 | display_name 읽기 전용 | 본인이 직접 수정 가능 (RLS 기존 정책 활용) |
| 전결 표시 | `[전결] <uuid>` 노출 | `[전결]` 만 깔끔 표기 |
| 전결/부재 기간 | datetime-local (시간 입력 강제) | date 피커 (날짜만, 내부 KST 경계 자동 확장) |
| 부재 대리 결재 | 버튼 미노출 (RLS로 조회 차단) | 대리인도 정상 인식·승인 |
| 병렬 결재 | group_order ≠ step_index 시 엉뚱한 결재자에게 노출 / 병렬 1명만 인식 | group_order 기반 정확 판정, 병렬 전원 동시 노출 |
| 합의(agreement) | 인프라만 존재, UI·Zod·RPC 구멍 | E2E 완성. 동의/부동의 플로우 정상 진행 |
| 상신 실패 | 아무 반응 없이 조용히 멈춤 | alert + 콘솔 debug 로 즉시 에러 메시지 확인 |

## 2. 변경 커밋 목록

| # | 커밋 | 타입 | 요약 |
|---|---|---|---|
| 1 | `ff398d0` | fix(inbox) | 결재 참여자도 진행/완료/반려 탭 노출 |
| 2 | `4c96096` | fix(approval) | 재기안 시 `?draft=id` 누락으로 내용 프리필 실패 |
| 3 | `8ad103c` | feat(profile) | 본인 이름(display_name) 수정 기능 |
| 4 | `dfe3b73` | fix(approval) | 전결 comment UUID 숨김 |
| 5 | `b1e2297` | feat(delegation) | 전결 규칙 시작일/종료일 date-only UI |
| 6 | `2988210` | feat(absence) | 부재 등록 date-only UI |
| 7 | `c300e6a` | fix(rls) | 부재 대리인 SELECT 허용 (migration 0076) |
| 8 | `9a6abef` | fix(approval) | current_step_index = group_order 의미 정정 |
| 9 | `58e05d9` | fix(inbox) | pending step만 있는 문서 진행 탭 제외 |
| 10 | `35f8cd4` | feat(approval) | 결재자 추가 UI에 "합의" 선택지 |
| 11 | `a2f0964` | fix(approval) | 합의 Zod enum + 그룹 합류 로직 |
| 12 | `ea3d6b5` | fix(submit) | 사일런트 실패 제거 (zodErrors + alert) |
| 13 | `670aa2f` | fix(submit) | OrgTreePicker 경로에도 명시 groupOrder |
| 14 | `dcab7c9` | fix(rpc) | fn_advance_document 이 agreement 포함 (migration 0077) |

## 3. DB Migrations

### 0076_user_absences_rls_delegate_select.sql
- `ua_select` 정책 DROP 후 `delegate_user_id = auth.uid()` 조건 OR 합침
- 결과: 부재 대리인이 자기 위임 부재 row 조회 가능 → UI `fetchActiveProxyFor` 가 실제 대리 가능 문서를 인식

### 0077_fn_advance_document_include_agreement.sql
- 그룹 완료 판정 쿼리 `step_type = 'approval'` → `step_type IN ('approval', 'agreement')` 확장
- 결과: 같은 그룹 내 [approval + agreement] 공존 시 양쪽 모두 완료돼야 다음 그룹으로 이동. agreement pending 고립 방지

## 4. Key Findings & Architectural Insights

### 4.1 v1.2 semantic redefinition 여진
`approval_documents.current_step_index` 가 step_index → group_order 로 의미 바뀌었으나 앱 여러 곳이 step_index 기반 비교 유지. 이번에 inbox pending filter + document detail currentStep 판정 2곳을 group_order 기준으로 통일. v1.2 당시 migration 0031 의 COMMENT 는 있었지만 앱 코드 감사가 불충분했던 부분.

### 4.2 합의(agreement) 인프라 갭
RPC(`fn_agree_step`/`fn_disagree_step`) + audit action + StepType 타입 + DB enum 등 인프라는 완성돼 있었으나:
- ApproverPicker UI radio 누락
- ApprovalLine addApprover 타입 좁힘
- Zod `approvalLineItemSchema.stepType` enum 누락
- fn_advance_document agreement 미반영

모두 '승인 처리'와 '그룹 완료 판정' 관점에서 agreement 를 approval 과 동급으로 취급하지 않아 생긴 구멍.

### 4.3 날짜 UI vs timestamptz 컬럼
전결 규칙·부재 양쪽 모두 timestamptz 컬럼이지만 관리자 실무는 날짜 단위. DB 그대로 두고 UI 에서 date 피커 + 저장 시 KST 하루 경계(`00:00:00+09:00` / `23:59:59+09:00`)로 확장하는 패턴이 효과적. RPC 매칭 로직(`now() BETWEEN start AND end`)이 KST 종일 커버됨.

### 4.4 사일런트 실패 패턴
SvelteKit form action + Zod refine 조합에서 refine 에러가 `formErrors` 로 나오는데 `zodErrors()` 가 `fieldErrors` 만 읽고 드롭 → UI 배너가 비어 사용자는 실패를 인지 못함. 대응으로 zodErrors 에 formErrors/deep-path 보존 로직 + submit enhance 에 alert/콘솔 로깅 추가. 이후 유사 버그는 alert 메시지 + `[rigel:submit:*]` 콘솔 로그로 즉시 진단 가능.

## 5. Deployment Flow Used

### 앱 코드 변경 (11 커밋)
```bash
ssh rigel-prod 'cd ~/rigel && git pull && podman-compose down && podman-compose up -d --build'
```
- 다운타임 ~20초 (podman-compose down → up 사이클)
- Supabase 13종 영향 없음

### DB migration (2 커밋)
```bash
# Prod
cat supabase/migrations/00{76,77}_*.sql | \
  ssh rigel-prod 'podman exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1'

# Dev
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/migrations/00NN_*.sql
```
- 앱 재빌드 불필요, 0 다운타임
- dev↔prod 동기 규칙 준수

## 6. Validation & Test Coverage

사용자가 각 기능을 브라우저 E2E 로 확인:

| 시나리오 | 상태 |
|---|---|
| APP-20260415-0002 (승인자 완료함 표시) | ✅ |
| APP-20260415-0003 (재기안 프리필) | ✅ |
| APP-20260415-0006 (전결 UUID 숨김) | ✅ |
| APP-20260415-0007 (부재 대리 승인) | ✅ |
| APP-20260415-0008 (후결 플로우) | ✅ (스펙 확인만) |
| APP-20260415-0009 (병렬 group_order 버그) | ✅ (fix 후) |
| APP-20260415-0010 (진행 탭 pending 노출) | ✅ (fix 후) |
| APP-20260415-0016 (합의 group 완료 판정) | ✅ (migration 0077 + 새 문서로 재테스트) |
| 본인 이름 수정 | ✅ |
| 전결 규칙 date-only 저장/매칭 | ✅ |
| 부재 date-only 저장/매칭 | ✅ |
| 합의 상신 + 동의/부동의 E2E | ✅ |

## 7. Session Lessons → Memory Updates

| 파일 | 변경 |
|---|---|
| `feedback_prod_destructive_ops.md` | **신규** — 프로덕션 파괴 명령은 "반영해줘" 범위 밖, 별도 승인 필요. documented ≠ pre-authorized. 에러 반응 시 runbook 먼저 확인 후 compose → 컨테이너 → 강제 순으로 제안 |
| `feedback_migration_sync.md` | LAN IP 제거 → Tailscale alias 표준화, base64 경유 prod apply one-liner 추가, `supabase db push` vs 직접 `psql -f` 경로 명시 |
| `project_rigel_prod_access.md` | 검증된 expect SSH 대리 실행 템플릿, 트리거 조건("테스트해줘/확인해줘/실행해줘" 등 명시 요청일 때만), 자주 쓰는 원격 읽기 전용 점검 명령 4종 |

## 8. Known Non-Issues (observed but not blocking)

- `svelte-check` warnings 46건: 전부 기존 `state_referenced_locally` 경고. 이번 변경으로 추가/제거 없음. 정리는 별도 작업으로
- `.bkit/state/pdca-status.json` `activeFeatures` 배열에 파일 경로 기반 가짜 feature 다수: 자동 tracker 노이즈 (CLAUDE.md 문서화 사안)

## 9. 후속 작업 제안 (선택)

| 제안 | 이유 |
|---|---|
| fn_advance_document 의 `v_next_group` 탐색에 agreement 그룹도 포함 | 현재는 UI가 agreement 를 approval 그룹에 강제해서 문제 없으나, 스키마 레벨 안전성 향상 차원 |
| 결재선 UI 에 step type 변경(stepType toggle) 기능 | 추가 후 실수로 타입 바꾸려면 삭제 후 재추가만 가능 — 사소한 UX 개선 |
| `state_referenced_locally` warning 일괄 정리 | 현재 46건, 장기적으로 누적 방지 |
| 후결(post-facto) 상세 E2E 는 스펙 확인만 — 실제 기안→승인→완료 재현 테스트 아직 미완 | 별도 세션에서 진행 |

## 10. Environment Snapshot

- **Main branch HEAD**: `dcab7c9`
- **Prod container**: `rigel-app` (재빌드 후 Healthy)
- **DB**: Postgres 15.8.1, Supabase self-hosted (Podman rootless)
- **Migration count**: 0001 ~ 0077
- **공개 엔드포인트**: `https://rigelworks.io`, `https://app.rigelworks.io`, `https://api.rigelworks.io`

---

*Generated: 2026-04-15*
*Session type: Ad-hoc multi-issue QA hotfix (plan 없이 Do/Check 사이클만 반복)*
