# Errata — 전자결재 v1.1 Korean Exceptions

> `design.md`의 일부 타입·RPC 시그니처·컬럼 이름이 구현된 실제 코드와 일치하지 않습니다.
> 이 문서는 **실제 구현이 authoritative** 라는 전제로 drift 지점을 기록합니다.
> 작성일: 2026-04-11 (v1.2 착수 전 잔여 정리 G2)

**적용 원칙**: design.md 는 원문 그대로 보존합니다. 이후 참조자는 본 ERRATA 를 우선으로 읽으세요.

---

## 1. `DocumentStatus` enum (design §1.1)

| 위치 | 값 |
|---|---|
| design.md §1.1 (원문) | `'draft' \| 'pending' \| 'approved' \| 'rejected' \| 'withdrawn' \| 'pending_post_facto'` |
| **실제 (v1.1)** | `'draft' \| 'in_progress' \| 'pending_post_facto' \| 'completed' \| 'rejected' \| 'withdrawn'` |

- `pending` → `in_progress` 로 고정 (v1.0 Plan 결정 유지)
- `approved` → `completed` (최종 상태)
- 출처: `src/lib/types/approval.ts:100`, `supabase/migrations/0009_approval_documents.sql` (enum `public.document_status`)

## 2. `AuditAction` enum (design §1.1)

| 위치 | 값 |
|---|---|
| design.md §1.1 (원문) | `'submitted' \| 'approved' \| 'rejected' \| 'withdrawn' \| 'commented' \| 'skipped' \| 'delegated' \| 'approved_by_proxy' \| 'submitted_post_facto' \| 'auto_delegated'` |
| **실제 (v1.1)** | `'draft_saved' \| 'submit' \| 'approve' \| 'reject' \| 'withdraw' \| 'comment' \| 'delegated' \| 'approved_by_proxy' \| 'submitted_post_facto' \| 'auto_delegated'` |

- v1.0 이 과거형 동사(`submitted`, `approved`) 대신 **명령형 동사**(`submit`, `approve`) 를 채택함. design 초안은 과거형으로 잘못 기재.
- `skipped` 액션은 존재하지 않음 → delegation 은 `'delegated'`, reference step 자동 완료는 `comment` 또는 payload 로 구분.
- `commented` → `comment`, `withdrawn` → `withdraw`.
- v1.0 이 `draft_saved` 도 사용 (임시저장 감사) → design 에 누락.
- 출처: `src/lib/types/approval.ts:152-163`, `supabase/migrations/0012_approval_audit_logs.sql` (enum `public.audit_action`)

## 3. `fn_submit_draft` signature (design §2.3)

design.md §2.3 의 다음 블록은 **무효**:

```sql
CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_form_id uuid,
  p_title text,
  p_data jsonb,
  p_approver_line jsonb,
  p_attachments jsonb DEFAULT '[]'::jsonb
) RETURNS uuid
```

### 실제 시그니처 (`supabase/migrations/0021_fn_submit_draft_v2.sql:16`)

```sql
CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,
  p_attachment_ids uuid[] DEFAULT '{}'::uuid[],
  p_document_id uuid DEFAULT NULL
)
RETURNS public.approval_documents
```

변경점 요약:

| 항목 | design 초안 | 실제 |
|---|---|---|
| 파라미터 수 | 5 | 6 |
| `p_tenant_id` | 없음 (form 에서 유도) | **명시 전달 + `is_tenant_member` 체크** |
| 본문 파라미터 | `p_title` + `p_data` | `p_content` 만 (title 컬럼 없음 — `content` JSONB 내부) |
| 결재선 | `p_approver_line` `{user_id, role}` | `p_approval_line` `{userId, stepType}` |
| 첨부 | `p_attachments jsonb` | `p_attachment_ids uuid[]` (사전 업로드된 row id 배열) |
| Draft 재사용 | 없음 | `p_document_id` — 기존 draft 행 UPDATE-and-submit 지원 |
| 반환 | `uuid` | `public.approval_documents` (전체 row) |

v1.0 의 `fn_submit_draft` 와 **v1.1 교체본 0021 의 signature 가 동일** (v1.1 은 내부 로직만 확장). 즉 호출부 수정 없이 delegation 매칭이 추가된 것이 설계 목표였고, 설계서는 이 동일성을 적지 못하고 새 signature 를 상상해서 작성한 오류.

## 4. `approval_documents` 컬럼 (design §2.3 INSERT 블록)

| 컬럼 | design 초안 | 실제 |
|---|---|---|
| drafter | `drafter_user_id` | `drafter_id` |
| 본문 | `title text` + `data jsonb` | `content jsonb` (title 컬럼 없음) |
| 상태 초기값 | `'pending'` | `'in_progress'` (정상 상신) / `'pending_post_facto'` (후결) |
| 스냅샷 | `form_schema_snapshot jsonb` | 동일 |
| 스텝 인덱스 | 언급 없음 | `current_step_index int` 필수 (v1.0 부터) |

출처: `supabase/migrations/0009_approval_documents.sql`

## 5. `approval_steps` 컬럼 (design §2.3 INSERT 블록)

| 컬럼 | design 초안 | 실제 |
|---|---|---|
| 순서 | `step_order int` | `step_index int` |
| 타입 | `role text` (`'approver' \| 'reviewer'`) | `step_type public.step_type` (`'approval' \| 'reference'`) |
| 승인자 | `approver_user_id` | 동일 |
| 상태 | `status text` | `status public.step_status` (`'pending'/'approved'/'rejected'/'skipped'`) |
| 코멘트/액션시각 | 언급 없음 | `acted_at timestamptz`, `comment text` |
| 대리 | 언급 없음 | `acted_by_proxy_user_id uuid` (v1.1 M12 `0023_proxy_columns.sql` 추가) |

출처: `supabase/migrations/0010_approval_steps.sql` + `0023_proxy_columns.sql`

## 6. `approval_audit_logs` 컬럼 (design §2.3 INSERT 블록)

| 컬럼 | design 초안 | 실제 |
|---|---|---|
| 행위자 | `actor_user_id` | `actor_id` |
| 페이로드 | `comment text` | `payload jsonb` (+ `comment` 사용 사례는 payload 안에 nested) |
| action enum 값 | `'submitted'`, `'delegated'` | `'submit'` (명령형), `'delegated'` |

출처: `supabase/migrations/0012_approval_audit_logs.sql`

---

## 7. 영향 평가

- **코드**: 없음. 모든 실 구현은 실제 스키마·시그니처로 일관되게 작성됨. svelte-check 0 error, 25/40 smoke pass.
- **문서 독자**: design.md §2.3 블록을 그대로 카피해 다른 RPC 작성 시 컴파일 실패 → 반드시 본 ERRATA 참조.
- **v1.2 Plan 작성 시**: v1.2 design 초안은 **실제 컬럼·enum** 기준으로 작성할 것. design 템플릿 카피 금지.

## 8. design.md 에 수정을 가하지 않은 이유

- 아카이브 원본은 incremental 개선 이력의 근거로 보존 (PDCA Report 와 교차 참조)
- 수정 시 git blame chain 깨짐 + 기존 link 깨짐
- ERRATA 방식이 표준 학술 관행에도 부합

## 9. 다음 조치

- v1.2 Plan Plus 작성 시 design.md §1/§2 는 참조하지 말고 **본 ERRATA + `src/lib/types/approval.ts` + 실 migration** 을 authoritative source 로 사용
- v1.2 Risk table 에 "R: design drift 재발 방지" 항목 추가 권장 — Design 작성 직후 `svelte-check` 와 `grep` 로 실제 컬럼·enum 값을 cross-check 하는 체크포인트
