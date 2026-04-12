# Plan — 전자결재 v1.1 Korean Exceptions

> 전결·대결·후결·부재자동 (한국형 결재 예외 4종)
> 베이스: v1.0.0 (`d957381`, 25 smoke 통과, match 100%)
> 작성일: 2026-04-11
> 작성 방식: Plan Plus (brainstorming-enhanced)

---

## Executive Summary

| 항목 | 값 |
|---|---|
| Feature | 전자결재-v1.1-korean-exceptions |
| 베이스 | v1.0.0 (approval-mvp 완료) |
| Delivery 전략 | Sequential 4-Slice (M11→M12→M13→M14) |
| 예상 migration | 0019~0029 (11건) |
| 예상 smoke 추가 | +15 (25 → 40) |
| 주요 Risk | 전결↔부재 충돌, 후결 원자성, pg_cron 멱등성 |
| 문서 경로 | `docs/01-plan/features/전자결재-v1.1-korean-exceptions.plan.md` |

### Value Delivered (4-Perspective)

| 관점 | 내용 |
|---|---|
| **Problem** | v1.0은 순차승인만 지원. 한국 SMB 그룹웨어 필수 요건인 전결(금액/양식별 위임), 대결(부재 시 대리), 후결(긴급 사후결재), 부재자동 전환이 부재하여 실사용 불가 |
| **Solution** | 4종 예외를 DB·RPC·UI 레이어 전반에 스냅샷·원자성·감사로그 원칙 준수 상태로 통합. Sequential 4-slice로 리스크 최소화 |
| **Function UX Effect** | 부재 등록만으로 결재 자동 전환, 긴급건 즉시 후결 후 사후 승인 파이프라인, 금액/양식별 자동 전결로 승인 대기 시간 단축. Inbox 배지로 감사 투명성 확보 |
| **Core Value** | 한국 그룹웨어 표준 절차 충실도 확보 → v1.0 "기술 MVP"가 "시장 진입 MVP"로 전환. 컴플라이언스 감사 트레일 완비 |

---

## 1. User Intent Discovery (Phase 1)

### 1.1 Core Problem
v1.0 shippable core는 기본 순차승인·참조·JSON 양식까지만 구현. 한국 SMB가 실제 업무에 도입하려면 시장조사 보고서(`docs/01-research/korean-groupware-approval-review.md`)에서 필수로 꼽은 **전결·대결·후결·부재자동** 4종 예외가 필요. 없으면 실사용 불가.

### 1.2 Target Users
- **End user (기안자)**: 후결로 기안, 본인 부재 등록 (/my/absences)
- **End user (승인자·대리인)**: 대리 승인, 전결 자동 skip
- **Admin/Owner**: delegation_rules CRUD, 멤버 부재 CRUD
- **감사자 (잠재)**: audit_logs에서 대리/전결/후결/자동위임 이력 추적

### 1.3 Success Criteria
- 40개 smoke test 100% 통과 (v1.0 25 + v1.1 15 신규)
- Supabase advisor `auth_rls_initplan` · `multiple_permissive_policies` **0건**
- 4개 milestone 모두 독립 dogfood 가능
- 한국형 시나리오 ("팀장 부재 중 급한 계약서 후결") 엔드투엔드 성공

### 1.4 Intent Discovery 결정 로그

| 질문 | 선택 | 근거 |
|---|---|---|
| v1.1 스코프 | **4종 전부** | memory 가이드 그대로 풀스코프. 한국 시장 표준이 4종 한 덩어리로 인식됨 |
| 전결↔부재 우선순위 | **부재 > 전결** | 대기 업무 연속성 최우선. 사용자 모델 단순 (단일 대리인) |
| 후결 원자성 | **단일 TX + FOR UPDATE** | v1.0 fn_submit_draft 패턴 확장, 부분 실패 상태 노출 방지 |
| 부재 자동 전환 트리거 | **Trigger + 매일 00:00 cron 백업** | 반응성 최상 + 멱등성 확보 쉬움 |

---

## 2. Alternatives Explored (Phase 2)

### 2.1 Delivery 전략 3안 비교

| | A. Sequential 4-Slice ★ | B. Layered | C. Value-Paired 2-Bundle |
|---|---|---|---|
| 배송 단위 | M11→M12→M13→M14 각각 | DB→RPC→UI 일괄 | 위임계열 / 시간계열 2 Bundle |
| Dogfood 가능 시점 | 각 마일스톤 직후 | 전체 완료 후 | 각 Bundle 완료 후 |
| Rollback 단위 | 슬라이스 1개 | 전체 | Bundle 1개 |
| Admin UI 수정 횟수 | 4 | 1 | 2 |
| v1.0 검증 리듬과 호환 | ✅ (M1~M10과 동일) | ❌ | ➖ |
| 채택 | **★** | | |

### 2.2 채택 이유
- v1.0 M1~M10 리듬이 이미 25 smoke / 100% match로 검증 완료
- 각 슬라이스가 독립 smoke-testable → regression 원인 지목 용이
- 전결→대결→후결→부재자동 순서는 의존성 자연 연결 (전결 기준 확정 후 부재 오버라이드 설계)
- Dogfood가 M11 직후부터 가능 → 시장 피드백 조기 수집

---

## 3. YAGNI Review (Phase 3)

### 3.1 v1.1 포함 (Included)

**Core (자동 포함)**
- [x] delegation_rules 테이블·RLS
- [x] user_absences 테이블·RLS
- [x] approval_steps/audit_logs proxy 컬럼
- [x] approval_documents.status += 'pending_post_facto'
- [x] fn_submit_post_facto RPC
- [x] fn_approve_step proxy 확장
- [x] user_absences trigger + pg_cron 백업
- [x] audit_action enum 확장 (delegated/approved_by_proxy/submitted_post_facto/auto_delegated)

**Delegation 정밀도**
- [x] amount_limit (금액 기준 전결)
- [x] form_id nullable (양식별 전결)
- [x] effective_from/to (효력기간)
- [x] 위임 체인 깊이 제한 (depth ≥ 2 reject)

**Absences 정밀도**
- [x] absence_type enum (annual/sick/business_trip/other)
- [x] scope_form_id (전체 vs 특정 form)

**Post-facto / UI**
- [x] 후결 사유 필수 (reason NOT NULL)
- [x] Admin UI: /t/[slug]/admin/delegations CRUD
- [x] Admin UI: /t/[slug]/admin/absences CRUD
- [x] Self-service UI: /t/[slug]/my/absences
- [x] Inbox 배지 (대리/전결/후결)

### 3.2 v1.1 제외 → 후속 버전 (Out of Scope)

| 항목 | 이관 버전 | 사유 |
|---|---|---|
| 병렬결재 · 합의 (parallel_groups) | v1.2 | 독립 설계 필요, 시나리오 격리 가능 |
| PDF 출력 · 해시 · 서명이미지 | v1.2 | 저장·signing 인프라 별도 |
| Realtime 알림 (Supabase Realtime) | v1.3 | 이메일과 세트로 설계 |
| 이메일 알림 | v1.3 | SMTP 인프라 선행 필요 |
| 모바일 반응형 고도화 | v1.3 | v1.0의 기본 반응형으로 당분간 충분 |
| Google Calendar 연동 (부재 자동 감지) | v1.3+ | OAuth 통합 선행 |
| 결재선 빌더 · 자동 라우팅 엔진 | v2 | 별도 대형 워크스트림 |

### 3.3 YAGNI 원칙 적용
- delegation_rules 매칭 로직은 RPC 내부 한 함수로 구현 (helper 분리 금지)
- Admin/Self-service UI는 별도 컴포넌트 추상화 없이 v1.0 `admin/members` · `admin/forms` 패턴 직접 복제
- Inbox 배지는 ApprovalLine 컴포넌트 내부 `{#if}` 브랜칭만 추가 (새 컴포넌트 생성 금지)

---

## 4. Architecture Overview

### 4.1 Milestone Map

| MS | 이름 | Migration | RPC | UI | Smoke |
|---|---|---|---|---|---|
| **M11** | 전결 (Delegation) | 0019, 0020, 0021 | fn_submit_draft v2 | /admin/delegations (신규) | +4 |
| **M12** | 대결 (Proxy) | 0022, 0023, 0024 | fn_approve_step 확장 | /admin/absences, /my/absences (신규) | +5 |
| **M13** | 후결 (Post-facto) | 0025, 0026 | fn_submit_post_facto | drafts/new 후결 토글 | +3 |
| **M14** | 부재 자동 전환 | 0027, 0028, 0029 | fn_auto_delegate_on_absence | Inbox 배지 (ApprovalLine) | +3 |

### 4.2 Migration 목록

```
0019_delegation_rules.sql            # 테이블 + RLS + 인덱스
0020_audit_action_delegated.sql      # ALTER TYPE ADD VALUE (TX 외부)
0021_fn_submit_draft_v2.sql          # 결재선 구성 시 delegation 매칭 & step skip
0022_user_absences.sql               # absence_type enum + 테이블 + RLS
0023_proxy_columns.sql               # approval_steps, audit_logs 컬럼 추가
0024_fn_approve_with_proxy.sql       # fn_approve_step 확장 (proxy 로직)
0025_post_facto_status.sql           # document_status += 'pending_post_facto', audit += 'submitted_post_facto'
0026_fn_submit_post_facto.sql        # 후결 RPC (단일 TX + FOR UPDATE)
0027_fn_auto_delegate_on_absence.sql # 부재 시 재배정 로직
0028_absence_trigger.sql             # user_absences AFTER INSERT/UPDATE
0029_pg_cron_absence_backup.sql      # 매일 00:00 백업 job
```

**주의**: `ALTER TYPE ADD VALUE`는 트랜잭션 외부에서만 실행 → 0020/0025는 단독 파일 분리.

---

## 5. Data Model

### 5.1 delegation_rules (M11)

```sql
CREATE TABLE delegation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  delegator_user_id uuid NOT NULL REFERENCES auth.users(id),  -- 위임자
  delegate_user_id  uuid NOT NULL REFERENCES auth.users(id),  -- 전결 수행자
  form_id uuid NULL REFERENCES approval_forms(id),            -- NULL=전체
  amount_limit numeric(14,2) NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to   timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES auth.users(id),
  CHECK (delegator_user_id <> delegate_user_id),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);
CREATE INDEX idx_delegation_rules_lookup
  ON delegation_rules (tenant_id, delegator_user_id, form_id, effective_from);
```

**RLS** (모든 정책 `(SELECT auth.uid())` 래핑, action별 단일):
- SELECT: `is_tenant_member(tenant_id, (SELECT auth.uid()))`
- INSERT/UPDATE/DELETE: tenant owner 또는 admin

**매칭 우선순위** (fn_submit_draft 내부):
1. `form_id = doc.form_id AND (amount_limit IS NULL OR amount <= amount_limit)` → 구체 우선
2. `form_id IS NULL AND (amount_limit IS NULL OR amount <= amount_limit)` → 전체 전결
3. `effective_from <= now() AND (effective_to IS NULL OR effective_to > now())`
4. 여러 규칙 매칭 시 `ORDER BY (form_id IS NULL) ASC, amount_limit ASC NULLS LAST, effective_from DESC LIMIT 1`

### 5.2 user_absences (M12)

```sql
CREATE TYPE absence_type AS ENUM ('annual','sick','business_trip','other');

CREATE TABLE user_absences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  delegate_user_id uuid NOT NULL REFERENCES auth.users(id),
  absence_type absence_type NOT NULL DEFAULT 'other',
  scope_form_id uuid NULL REFERENCES approval_forms(id),      -- NULL=전체
  start_at timestamptz NOT NULL,
  end_at   timestamptz NOT NULL,
  reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (user_id <> delegate_user_id),
  CHECK (end_at > start_at)
);
CREATE INDEX idx_user_absences_active
  ON user_absences (tenant_id, user_id, start_at, end_at);
```

**RLS**:
- SELECT: 본인 OR tenant owner/admin
- INSERT: 본인 OR tenant owner/admin (self-service + admin 모두 지원)
- UPDATE/DELETE: 본인 OR tenant owner/admin
- 모두 action별 단일 정책, `(SELECT auth.uid())` 래핑

### 5.3 Proxy Columns (M12)

```sql
ALTER TABLE approval_steps
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id);

ALTER TABLE approval_audit_logs
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id);
```

- `acted_by_proxy_user_id` NULL → 본인이 직접 승인
- NOT NULL → 해당 값이 실제 action을 수행한 대리인

### 5.4 Enum 확장

```sql
-- 0020 (M11)
ALTER TYPE audit_action ADD VALUE 'delegated';

-- 0023 (M12, 0024 RPC 내부에서 사용)
ALTER TYPE audit_action ADD VALUE 'approved_by_proxy';

-- 0025 (M13)
ALTER TYPE document_status  ADD VALUE 'pending_post_facto';
ALTER TYPE audit_action     ADD VALUE 'submitted_post_facto';

-- 0027 (M14)
ALTER TYPE audit_action ADD VALUE 'auto_delegated';
```

---

## 6. RPC Contracts

### 6.1 fn_submit_draft v2 (M11, 교체)

```
INPUT : p_form_id uuid, p_title text, p_data jsonb,
        p_approver_line jsonb, p_attachments jsonb
OUTPUT: approval_documents.id uuid

FLOW:
  1. SELECT form FOR UPDATE (snapshot 확보, v1.0 동일)
  2. INSERT approval_documents (status='pending')
  3. FOR each approver IN p_approver_line:
       매칭되는 delegation_rule 검색 (5.1 매칭 우선순위)
       IF 매칭: step status='skipped' + audit 'delegated' (delegator_user_id 참조)
       ELSE   : step status='pending' (v1.0 동일)
  4. INSERT audit 'submitted'

RULES:
  - 모든 delegation 매칭은 snapshot 시점에 확정 (상신 이후 규칙 변경 영향 없음)
  - step_order 유지 (skip된 스텝도 자리 차지)
```

### 6.2 fn_approve_step (M12, proxy 확장)

```
INPUT : p_step_id uuid, p_comment text
OUTPUT: void

FLOW:
  1. SELECT step FOR UPDATE
  2. acting_user := (SELECT auth.uid())
  3. IF step.approver_user_id = acting_user:
       정상 승인 경로 (v1.0 그대로)
     ELSE:
       active user_absences 조회:
         WHERE user_id = step.approver_user_id
           AND now() BETWEEN start_at AND end_at
           AND (scope_form_id IS NULL OR scope_form_id = doc.form_id)
       IF absence.delegate_user_id = acting_user:
         # 체인 깊이 제한
         IF EXISTS (active absence WHERE user_id = acting_user):
           RAISE EXCEPTION 'proxy chain depth exceeded'
         대리 승인 실행: acted_by_proxy_user_id = acting_user
         audit action='approved_by_proxy', acted_by_proxy_user_id=acting_user
       ELSE:
         RAISE EXCEPTION 'not authorized'
  4. (v1.0 Risk #13 로직 유지) 마지막 승인 시 pending reference 스텝 일괄 skipped
```

### 6.3 fn_submit_post_facto (M13)

```
INPUT : p_form_id uuid, p_title text, p_data jsonb,
        p_approver_line jsonb, p_reason text (NOT NULL)
OUTPUT: approval_documents.id uuid

FLOW (단일 TX, FOR UPDATE):
  1. IF p_reason IS NULL OR length(trim(p_reason)) = 0:
       RAISE EXCEPTION 'post-facto reason required'
  2. SELECT form FOR UPDATE
  3. INSERT approval_documents (status='pending_post_facto',
                                form_schema_snapshot=form.schema)
  4. INSERT approval_steps (pending, v1.0와 동일 결재선)
  5. INSERT audit 'submitted_post_facto' (comment=p_reason)
  6. RETURN document.id

NOTE:
  - delegation 매칭은 fn_submit_draft와 동일하게 적용
  - 승인 완료 시 상태가 'pending' → 'approved'로 전환 (별도 트랜잭션 없음)
  - 사후 결재 거부 시 상태는 'rejected' (원복 로직 없음 — 감사 추적성 우선)
```

### 6.4 fn_auto_delegate_on_absence (M14)

```
INPUT : p_absence_id uuid
OUTPUT: int (재배정된 step 수)

FLOW:
  1. SELECT absence FROM user_absences WHERE id = p_absence_id
  2. UPDATE approval_steps
       SET approver_user_id = absence.delegate_user_id,
           acted_by_proxy_user_id = NULL  -- trigger는 '재배정'일 뿐, action은 아직 없음
     WHERE status = 'pending'
       AND approver_user_id = absence.user_id
       AND (absence.scope_form_id IS NULL
            OR doc.form_id = absence.scope_form_id)
       AND tenant_id = absence.tenant_id
  3. FOR each updated step: INSERT audit 'auto_delegated'
  4. RETURN count

멱등성:
  - 이미 delegate_user_id로 재배정된 행은 WHERE 조건에서 자연 제외
  - cron 백업 실행 시 누락분만 추가 반영
```

### 6.5 Trigger & Cron (M14)

```sql
-- 0028
CREATE TRIGGER trg_absence_auto_delegate
  AFTER INSERT OR UPDATE OF delegate_user_id, start_at, end_at, scope_form_id
  ON user_absences
  FOR EACH ROW
  WHEN (NEW.start_at <= now() AND NEW.end_at > now())
  EXECUTE FUNCTION fn_auto_delegate_on_absence_trigger();

-- 0029
SELECT cron.schedule(
  'absence-backup-00',
  '0 0 * * *',
  $$ SELECT fn_auto_delegate_on_absence(id)
       FROM user_absences
       WHERE now() BETWEEN start_at AND end_at $$
);
```

---

## 7. UI Surface

### 7.1 신규 라우트

| 경로 | 역할 | 권한 |
|---|---|---|
| `/t/[slug]/admin/delegations/` | 전결 규칙 목록·생성·수정·삭제 | owner / admin |
| `/t/[slug]/admin/delegations/new/` | 생성 폼 | owner / admin |
| `/t/[slug]/admin/delegations/[id]/` | 수정 폼 | owner / admin |
| `/t/[slug]/admin/absences/` | 전 멤버 부재 관리 | owner / admin |
| `/t/[slug]/my/absences/` | 본인 부재 등록·조회 | 멤버 본인 |

### 7.2 변경 라우트

| 경로 | 변경 내용 |
|---|---|
| `/t/[slug]/approval/drafts/new/[formCode]/` | "후결로 기안" 토글 + `reason` textarea (토글 ON일 때만 표시). Action에서 `is_post_facto` flag로 `fn_submit_post_facto` 라우팅 |

### 7.3 신규 서버 파일

```
src/lib/server/queries/delegations.ts       # profiles.ts 2-query join 패턴 재사용
src/lib/server/queries/absences.ts
src/lib/server/schemas/delegationRuleSchema.ts
src/lib/server/schemas/absenceSchema.ts
```

### 7.4 변경 컴포넌트

| 파일 | 변경 |
|---|---|
| `src/lib/components/ApprovalLine.svelte` | 스텝별 배지 렌더: `대리`(acted_by_proxy_user_id NOT NULL), `전결`(status=skipped with audit delegated), `후결`(doc.status=pending_post_facto) |
| `src/lib/components/ApprovalPanel.svelte` | active user_absence 감지 → "대리 승인" CTA 라벨 |
| `src/lib/types/approval.ts` | `DelegationRule`, `UserAbsence` 타입 추가 |

### 7.5 Svelte 5 / SvelteKit 규칙 (CLAUDE.md 재확인)

- Actions에서 `parent()` 불가 → `resolveTenant` inline
- 복잡 state 전송은 `use:enhance` 주입 (hidden input 금지)
- 에러 shape는 `$lib/forms.ts` FormErrors 사용
- `$state(data.x)` 경고 시 `untrack(() => [...data.x])`
- 양식 파일 2-query + Map join (profiles.ts 패턴 재사용)

---

## 8. Smoke Test Plan (v1.0 25 → v1.1 40)

### 8.1 M11 전결 (+4)

| # | 시나리오 | 기대 |
|---|---|---|
| S26 | amount 매칭 전결 | step skipped + audit delegated |
| S27 | form_id 매칭 전결 (전체 규칙 우선 덮음) | form-specific 우선 적용 |
| S28 | effective_to 경과 규칙 | 미적용 (정상 순차) |
| S29 | 여러 규칙 매칭 | 우선순위 ORDER BY대로 1건 선택 |

### 8.2 M12 대결 (+5)

| # | 시나리오 | 기대 |
|---|---|---|
| S30 | active absence 보유 승인자 → 대리인 승인 | 성공, acted_by_proxy 기록 |
| S31 | 비활성 absence (기간 외) | 대리 실패 (not authorized) |
| S32 | scope_form_id 불일치 | 대리 실패 |
| S33 | 대리인도 absence (체인 깊이 2) | RAISE depth exceeded |
| S34 | 정상 본인 승인에는 acted_by_proxy NULL | 유지 |

### 8.3 M13 후결 (+3)

| # | 시나리오 | 기대 |
|---|---|---|
| S35 | fn_submit_post_facto 정상 호출 | status=pending_post_facto, audit submitted_post_facto |
| S36 | reason 빈 문자열 | RAISE post-facto reason required |
| S37 | 후결 문서 정규 결재 진행 & 완료 | status→approved 정상 전환 |

### 8.4 M14 부재자동 (+3)

| # | 시나리오 | 기대 |
|---|---|---|
| S38 | absence INSERT → 즉시 재배정 | 대상 pending step approver 변경 + audit auto_delegated |
| S39 | 동일 absence 재실행 (cron) | 멱등 (count=0) |
| S40 | cron 누락분 복구 (trigger 실패 모의) | count>0 재배정 |

### 8.5 회귀 확인

- v1.0 S1~S25 모두 재통과 필수 (마일스톤별 실행)
- Supabase advisor **0 WARN** 유지

---

## 9. Risk Register

| # | Risk | Mitigation | 마일스톤 |
|---|---|---|---|
| R1 | 전결↔부재 충돌 | **정책 확정: 부재 > 전결**. fn_submit_draft은 delegation으로 skip, fn_approve_step은 proxy 먼저 체크 → 스텝이 skipped면 애초에 proxy 경로 불가 (자연 배타) | M11/M12 |
| R2 | 후결 원자성 | 단일 TX + `SELECT form FOR UPDATE`. 실패 시 전체 롤백 | M13 |
| R3 | pg_cron 멱등성 | UPDATE WHERE approver_user_id = absence.user_id (이미 재배정된 행 자연 제외) | M14 |
| R4 | audit enum backward compat | `ADD VALUE` append only. migration 파일을 트랜잭션 외부 실행 분리 | M11/M12/M13/M14 |
| R5 | 위임 체인 무한 루프 | RPC 내부 depth≥2 RAISE EXCEPTION | M12 |
| R6 | delegation_rules 여러 규칙 매칭 | ORDER BY (form 구체성 > amount 하한 > 최신) LIMIT 1 | M11 |
| R7 | proxy 권한 우회 시도 | RLS + RPC SECURITY DEFINER + acting_user 명시 체크 | M12 |
| R8 | trigger 실패 (네트워크/락 등) | 매일 00:00 cron 백업으로 복구 | M14 |
| R9 | Svelte 5 state stale bug 재발 | use:enhance 주입 패턴 엄수, admin 폼도 동일 | M11~M14 UI |

---

## 10. Plan Plus 의사결정 로그 (Brainstorming Log)

| Phase | 질문 | 결정 | 근거 |
|---|---|---|---|
| Phase 1 Q1 | v1.1 스코프 | 4종 전부 | 한국 시장 4종이 세트로 표준 |
| Phase 1 Q2 | 전결↔부재 | 부재 > 전결 | 업무 연속성 최우선, 단일 대리인 모델 |
| Phase 1 Q3 | 후결 원자성 | 단일 TX + FOR UPDATE | v1.0 fn_submit_draft 패턴 재사용 |
| Phase 1 Q4 | 부재자동 | Trigger + 매일 00:00 백업 cron | 반응성 + 멱등성 |
| Phase 2 | Delivery | Sequential 4-Slice (A) | v1.0 리듬 검증됨, rollback 단위 최소 |
| Phase 3 | YAGNI | 정밀도 전 항목 포함 | 시장 필수 요구, 나중 migration 비용 > 지금 구현 |
| Phase 4 (1/2) | DB Layer | 승인 | — |
| Phase 4 (2/2) | App Layer | 승인 | — |

---

## 11. Out of Scope (v1.2+)

| 항목 | 이관 |
|---|---|
| 병렬결재 · 합의 · 협조 병렬 처리 | v1.2 |
| PDF 출력 · 본문 해시 · 서명 이미지 | v1.2 |
| Realtime (Supabase Realtime) | v1.3 |
| 이메일 알림 (SMTP) | v1.3 |
| 모바일 반응형 고도화 | v1.3 |
| Google Calendar 부재 자동 감지 | v1.3+ |
| 결재선 빌더 · 자동 라우팅 | v2 |

---

## 12. Next Steps

1. `/pdca design 전자결재-v1.1-korean-exceptions` — 상세 설계 문서 작성 (이 Plan을 §14로 확장, Risk Table §14, RLS 규칙 §2.0 재참조)
2. 마일스톤 M11부터 순차 착수 (PDCA Do phase)
3. 각 마일스톤 직후 smoke + `supabase.get_advisors` 실행
