# 한국형 그룹웨어 전자결재 시장 조사 및 기능 요구사항

> 작성일: 2026-04-11
> 목적: Rigel 프로젝트 "전자결재 시스템(결재폼 관리 포함)" PRD/Plan 진입 전 사전 조사

---

## 1. Executive Summary

- 한국 전자결재 시장은 SMB(다우오피스·두레이·카카오워크·플로우·네이버웍스)와 엔터프라이즈/공공(더존 WEHAGO·온나라·비즈메카 등)으로 이원화돼 있으며, 대부분 **결재선·양식 편집기·조직도 연동·모바일 결재**를 기본 축으로 공통 기능을 제공한다.
- 한국형 결재의 핵심은 **결재선(기안 → 검토/합의 → 협조 → 전결/승인 → 참조/공람)** 이라는 단일 워크플로우 위에 **전결·대결·후결·부재결재·병렬결재** 같은 예외 규칙이 얹히는 구조다. 글로벌 워크플로우 툴과 결정적으로 다른 지점이며 반드시 도메인 모델 레벨에서 표현돼야 한다.
- **자동결재선(조건 기반 규칙)** 과 **양식 빌더(드래그&드롭 + 조직도 연동 필드 + 수식)** 가 엔터프라이즈 전환의 분기점. 단순 기안 툴과 "진짜 그룹웨어 결재" 의 차이가 여기서 갈린다.
- 법적으로 전자문서법(2020 개정)과 전자서명법(2021 시행)에 의해 요건을 갖춘 전자결재 문서는 서면과 동일한 효력을 가지므로, **이력 무결성·전자서명·PDF 변환 보존**을 설계 초기부터 고려해야 한다.
- **SvelteKit 2 + Svelte 5(runes) + Supabase** 스택에서는 `hooks.server.ts`의 `safeGetSession` 게이트, `+layout.server.ts`/`+page.server.ts`의 서버 `load`, 결재 처리용 **Form Actions**, RLS 기반 부서·직급 권한 제어, Realtime 결재 알림, Storage 첨부·PDF 보존, pg_cron 기반 부재결재자 자동 전환이 핵심 구현 포인트다.

---

## 2. 시장 주요 서비스 비교표

| 서비스 | 제공사 | 주 타겟 | 배포형태 | 결재 핵심 강점 | 가격대(결재 포함 기준) |
|---|---|---|---|---|---|
| **두레이!(Dooray!)** | NHN Cloud | SMB~중견, 공공(CSAP) | SaaS(퍼블릭/전용), 온프레 일부 | 드래그&드롭 서식, 공용/개인 결재선, 부재 처리, 프로젝트·메신저와 한 UI | 프로젝트+메신저+결재 포함 1인/월 수천원대(플랜별) |
| **다우오피스** | 다우기술 | SMB~중견 | 클라우드 공용/전용, 온프레(구축형) | ~100종 샘플 양식, 양식 편집기, 자동결재선 규칙, 최대 10단계 결재선 | 공용형 4,000원/인·월, 전용형 5,000원/인·월(1GB 기준) |
| **WEHAGO / 더존 Office** | 더존비즈온 | SMB~엔터프라이즈, 세무회계사무소 | SaaS(WEHAGO), WEHAGO H(전용 클라우드), 온프레 | 전결·후결·대결·합의 풀 지원, ERP/회계/근태 상품과 직결, 태그 검색 | 상품 번들 구조(확인 필요) |
| **네이버웍스(NAVER WORKS)** | 네이버클라우드/웍스모바일 | SMB~엔터, 공공 패키지 존재 | SaaS | 일반·병렬 결재·합의·병렬합의·참조, 인사/조직발령 모듈, 근태·급여와 번들 | 결재 옵션 3,000원/인·월(연간), 4,000원/인·월(월간) |
| **카카오워크** | 카카오엔터프라이즈 | SMB | SaaS | 메신저 네이티브, 11종 기본 양식, 자유 템플릿, 실시간 알림/처리 | 무료 시작, 유료 플랜(확인 필요) |
| **플로우(Flow)** | 마드라스체크 | SMB~중견, 일부 대기업 구축형 | SaaS, 구축형(프라이빗) | 10년 협업툴 베이스, 결재선 지정만으로 즉시 사용, 알림봇 자동 안내, 메일·캘린더 번들 | 그룹웨어 기능(메일·결재·캘린더) 무료 번들 제공 |
| **온나라 2.0(참고)** | 행안부/가온아이 등 | 공공(중앙·지자체) | 정부 클라우드 | 부처간 공동기안·결재, ODF 기반, 대화형 UI, 비Active-X | 공공 조달 기준 |
| **비즈플레이(참고)** | 웹케시 | 경비/법인카드 특화 | SaaS | 회사규정 기반 자동결재선(금액·용도·영수증 종류) | - |

> 가격은 2024~2025 공개치 기준. 엔터프라이즈·공공 협약가는 비공개가 많아 "확인 필요" 영역.

---

## 3. 전자결재 도메인 모델

### 3.1 핵심 엔티티

```
User (사용자)
 └─ 소속: Department (부서), 겸직 가능 (N:N)
 └─ 직급/직책 (Position/JobTitle)
 └─ 위임/부재 설정 (DelegationRule)

Department (부서)
 └─ 트리 구조 (parent_id), 상위 부서 / 하위 부서
 └─ 부서장 지정 (head_user_id)

ApprovalForm (결재 양식)
 ├─ 카테고리 (인사/총무/재무/영업/구매 등)
 ├─ 양식 스키마 (JSON Schema 또는 필드 배열)
 ├─ 자동결재선 규칙 (조건부 라우팅)
 └─ 버전 관리 (form_version)

ApprovalDocument (결재 문서 = 기안된 인스턴스)
 ├─ form_id + form_version (어떤 양식의 어떤 버전으로 기안)
 ├─ drafter_user_id (기안자)
 ├─ payload (JSONB, 양식 필드 값)
 ├─ status (임시저장/상신/진행/완료/반려/회수)
 ├─ current_step_index
 └─ 첨부파일 (Attachment[])

ApprovalLine (결재선 - 문서별 스냅샷)
 └─ steps: ApprovalStep[]

ApprovalStep (결재 단계)
 ├─ step_order (1, 2, 3, …)
 ├─ step_type (결재 | 합의 | 병렬결재 | 병렬합의 | 협조 | 참조 | 공람)
 ├─ approver_user_id (또는 approver_dept_id)
 ├─ delegation_from_user_id (대결/전결 시 원 결재자)
 ├─ status (대기 | 승인 | 반려 | 대결 | 전결 | 보류)
 ├─ acted_at / comment / signature_ref
 └─ parallel_group_id (병렬 묶음)

ApprovalComment (결재 의견)
ApprovalHistory / AuditLog (감사 이력)
Attachment (첨부)
Signature (전자서명/도장 이미지)
```

### 3.2 관계 요약
- `Form 1 — N Document` (양식 한 종류로 여러 문서 기안)
- `Document 1 — 1 ApprovalLine — N ApprovalStep`
- `Step N — 1 User` (결재자)
- `Document 1 — N Attachment / Comment / AuditLog`
- `User N — N Department` (겸직)
- `Form 1 — N AutoLineRule` (자동 결재선 규칙)

---

## 4. 공통 기능 요구사항 (MUST)

한국형 그룹웨어 결재에서 **빠지면 사용자가 "이건 결재 시스템이 아니다" 라고 판단**하는 필수 기능.

### 4.1 결재선 구성
- 기안자가 상신 직전 결재선을 **수동 편집** 가능 (삽입/삭제/순서 변경)
- **개인 결재선 저장** (자주 쓰는 결재선 템플릿)
- **공용 결재선** (관리자가 부서/직책 기반으로 미리 정의)
- 결재 단계별 유형 지정: 결재 / 합의 / 협조 / 참조 / 공람
- **순차 결재**(기본) + **병렬 결재/병렬 합의**
- **합의 단계** 는 다른 부서 사전 동의, **협조** 는 사후 통지 성격 차이 반영

### 4.2 결재 처리
- 승인 / 반려 / 보류 / 반송(이전 단계로)
- **전결(專決)**: 상위 결재자를 건너뛰고 해당 단계에서 최종 확정 (전결권 설정 필요)
- **대결(代決)**: 결재권자 부재 시 지정된 대리인이 동일 효력으로 결재
- **후결(後決)**: 사후 결재 (선조치 후 추인)
- **회수**: 상신자가 결재 진행 중 회수 (보통 첫 결재자가 처리하기 전까지)
- 결재 의견 입력 필수/선택 설정

### 4.3 결재함
관찰된 주요 카테고리(카카오워크·다우오피스·네이버웍스 공통 + 두레이 확인):

| 함 | 용도 |
|---|---|
| 결재 대기함 | 내가 지금 처리해야 할 문서 |
| 진행함 | 내가 상신했고 진행 중인 문서 |
| 완료함 | 완전 승인 완료 문서 |
| 반려함 | 내가 반려했거나 내 기안이 반려된 문서 |
| 상신함 | 내가 기안한 전체 문서 이력 |
| 임시보관함 | 작성 중/저장만 된 문서 |
| 회수함 | 상신 후 회수한 문서 |
| 수신함 | 나를 수신자로 지정한 완료 문서 |
| 참조함 / 공람함 | 내가 참조·공람으로 지정된 문서 |

### 4.4 양식 관리
- 관리자가 양식 등록/수정/비활성화
- 양식 카테고리(폴더) 트리
- **양식 공개 범위** 설정 (전사/특정 부서/특정 직급만 기안 가능)
- 양식 버전 관리 (수정 시 기존 진행 문서는 원 버전 유지)

### 4.5 조직 연동
- 조직도 (부서 트리, 드래그&드롭 편집)
- 직급/직책 마스터
- 겸직 처리 (같은 사람이 여러 부서)
- 사용자 검색(이름/직급/부서 동시)
- 결재선 지정 시 조직도 모달 필수

### 4.6 부재/위임
- 개인 부재 일정 등록 → 기간 내 결재 자동 위임
- 위임 대상 지정 (특정 사용자 / 직책 대체 / 특정 양식에 한정)
- 부재 해제 시 원래 결재자에게 복귀

### 4.7 첨부 및 전자서명
- 첨부파일 다운로드/프리뷰 (이미지·PDF·오피스)
- 결재 도장(이미지) 자동 표시
- 전자서명 이력(누가, 언제, 어떤 IP/디바이스로)
- 완료 문서 **PDF 변환 보존** (결재 정보 워터마크 포함)

### 4.8 이력·감사
- 모든 결재 액션(상신/승인/반려/회수/대결/전결/의견)에 대한 타임스탬프 + 액터 + IP 기록
- 변경 불가(append-only) 원칙
- 관리자 전체 조회 권한 분리

### 4.9 알림
- 결재 대기 발생 시 실시간 알림(인앱 + 푸시 + 메일)
- 기안자에게 승인/반려 즉시 통보
- 장시간 미처리 시 리마인더

---

## 5. 차별화 기능 (SHOULD / COULD)

### 5.1 SHOULD
- **자동 결재선 규칙 엔진**: 양식별·부서별·금액구간별 결재선 자동 생성 (다우오피스·비즈플레이의 핵심 경쟁력)
- **전결권 규칙**: 금액 또는 품목 기준으로 "팀장이 전결 가능한 한도" 정의
- **양식 빌더(Drag&Drop)**: 비개발자 관리자가 필드 구성
- **수식 필드**: 표의 금액 합계, 단가×수량, 부가세 계산
- **문서 번호 자동 채번** (YYYY-부서-순번 등 포맷 설정)
- **모바일 결재 앱/반응형** (필수급이지만 수준 차이가 큼)
- **결재 문서 → 다른 시스템 연동**(회계 전표, 근태 신청, 구매 발주 자동 생성)

### 5.2 COULD
- **AI 기안 작성 보조**(최근 플로우·카카오워크가 방향 제시)
- **결재 문서 검색**(태그 기반 — WEHAGO가 도입)
- **공동 기안**(다수가 한 문서에 동시 편집 — 온나라가 부처간 공동기안 구현)
- **결재 진행 현황 타임라인 시각화**
- **다국어 양식**(글로벌 법인 대응)
- **OCR 영수증 인식 → 지출결의서 자동 채움**
- **외부 협력사 결재 초대**(합의 단계에 외부 이메일)

---

## 6. 결재 양식(폼) 카탈로그 — 기본 제공 표준 양식

한국 기업에서 범용적으로 기대되는 기본 양식. 다우오피스(약 100종) · 카카오워크(11종) · 네이버웍스 샘플 기준 교집합 + 실무 빈도 상위.

| # | 양식명 | 카테고리 | 대표 필드 |
|---|---|---|---|
| 1 | **일반 기안서(품의서)** | 총무/공통 | 제목, 기안 사유, 본문(리치텍스트), 첨부 |
| 2 | **지출 결의서** | 재무 | 지출 항목(표: 날짜/적요/금액/증빙), 총액(수식), 계정과목, 결제수단, 영수증 첨부 |
| 3 | **구매 요청서 / 구매 품의서** | 구매 | 품목(표: 품명/규격/수량/단가/금액), 납품요청일, 거래처, 사유 |
| 4 | **휴가 신청서(연차)** | 인사 | 휴가 종류(단일선택), 시작/종료 일시, 기간(수식), 사유, 비상연락처, 대체자 |
| 5 | **출장 신청서** | 인사/총무 | 출장지, 목적, 기간, 동행자(조직도), 예상 경비, 교통/숙박 |
| 6 | **출장 정산서(경비정산)** | 재무 | 출장 연동, 항목별 경비 표, 영수증, 선지급금, 실지급액(수식) |
| 7 | **업무 보고서(일/주/월간)** | 공통 | 보고 대상 기간, 수행 업무, 다음 계획, 이슈 |
| 8 | **회의록** | 공통 | 일시, 장소, 참석자(조직도), 안건, 결정사항, 액션아이템 |
| 9 | **법인카드 사용(지출) 내역서** | 재무 | 카드 선택, 사용 내역 표, 개인/법인 구분, 접대비 여부 |
| 10 | **경조금 신청서** | 인사/총무 | 경조 구분, 대상자와의 관계, 금액, 발생 일자, 계좌 |
| 11 | **인사 발령/채용 품의** | 인사 | 대상자, 직급, 발령 구분, 발효일 |
| 12 | **연장/야간/휴일 근무 신청서** | 인사 | 대상자, 일시, 사유, 예상 시간 |
| 13 | **휴직/복직 신청서** | 인사 | 휴직 구분, 기간, 사유, 첨부(진단서 등) |
| 14 | **계약서 검토/체결 품의** | 법무 | 상대방, 계약 유형, 금액, 기간, 계약서 첨부, 법무 합의 단계 |
| 15 | **외근/재택 신청서** | 인사 | 일시, 사유, 업무 계획 |

> 양식 10~15종으로 시작 → 사용자 커스텀 가능하도록. 다우오피스 수준(100종)은 중장기 과제.

---

## 7. 폼 빌더 설계 고려사항

### 7.1 필드 타입 (네이버웍스/두레이/다우오피스 확인 + 업계 표준)

| 타입 | 비고 |
|---|---|
| 텍스트(단/다중 라인) | 최대길이, placeholder |
| 리치 텍스트 | 본문용, 이미지 인라인 |
| 숫자 / 금액 | 통화 포맷, 한글 금액 병기("일백만원") |
| 날짜 / 날짜범위 / 시간 | 휴가·출장 등 필수 |
| 단일선택 / 다중선택 / 체크박스 | 옵션 동적 |
| 파일 첨부 | 개수·용량·MIME 제한 |
| **표(테이블)** | 행 추가/삭제, 셀별 타입(텍스트/숫자) |
| **조직도 사용자 픽커** | 단일/다중, 기본값="기안자 본인" |
| **부서 픽커** | |
| 주소 | 도로명 API 연동 |
| URL / 이메일 / 전화 | |
| **수식(Computed)** | 표 합계, 단가×수량, 총액 자동 |
| 숨겨진/메타 필드 | 기안자·기안부서·기안일시 자동 삽입 |
| 전자서명 블록 | 결재 완료 시 도장 배치 |

### 7.2 조건부 표시 (Conditional Logic)
- "휴가 종류 == 병가"일 때만 "진단서 첨부" 필드 노출
- "금액 > 500만원"일 때만 "CEO 결재 필수" 고정 단계 추가
- 규칙은 양식 스키마에 JSON으로 저장(경량 DSL)

### 7.3 수식(Computed)
- 셀 참조: `SUM(items.amount)`, `{items.quantity} * {items.unit_price}`
- 한글 금액 변환
- 서버 재계산 필수(클라이언트 위변조 방지)

### 7.4 양식 스키마 저장 방식
- `JSONB` 컬럼에 `{ version, sections: [{ fields: [...] }], rules: [...] }` 구조
- 버전 업 시 immutable copy. 이미 상신된 문서는 snapshot된 old schema로 렌더.

---

## 8. 결재선 규칙(자동결재선) 설계 고려사항

다우오피스·비즈플레이가 실무에서 가장 강조하는 부분. 규칙 엔진으로 구현.

### 8.1 규칙 구성 요소
```
AutoLineRule
 ├─ form_id (또는 global)
 ├─ priority (충돌 시 우선순위)
 ├─ condition (AND/OR 트리)
 │   예: amount >= 1000000 AND department IN ('영업팀', '마케팅팀')
 ├─ line_template
 │   예: [기안자 → 팀장 → 본부장 → CFO(금액≥500만 원일 때만)]
 └─ delegation (전결권: "팀장 전결 한도 100만원")
```

### 8.2 대표 규칙 예시
- **금액 구간별**
  - ~100만: 기안자 → 팀장(전결)
  - ~500만: 기안자 → 팀장 → 본부장(전결)
  - ~3000만: 기안자 → 팀장 → 본부장 → CFO(전결)
  - 3000만 초과: 기안자 → 팀장 → 본부장 → CFO → CEO
- **부서별**: 인사 관련 양식은 인사팀 합의 단계 자동 삽입
- **품목별**: 구매 품목이 "IT 장비"면 IT팀 협조 단계 자동 삽입
- **직급별**: 기안자가 임원이면 팀장 단계 스킵

### 8.3 충돌/적용
- 규칙 매칭 후 **기안자가 결재선을 수정**할 수 있어야 함(관리자가 고정 옵션도 가능)
- 고정 결재자(필수) vs 권장 결재자(편집 가능) 플래그

---

## 9. 데이터 모델 초안 (Supabase/PostgreSQL)

> SQL 상세 미포함. 테이블 · 주요 컬럼 · 관계 수준.

### 9.1 조직·사용자
- **departments**
  - `id`, `parent_id`, `name`, `code`, `head_user_id`, `sort_order`, `is_active`
- **positions** (직급)
  - `id`, `name`, `rank_level`(숫자, 서열 비교용)
- **users** (auth.users와 연계되는 profile)
  - `id(FK auth.users)`, `name`, `employee_no`, `email`, `primary_department_id`, `primary_position_id`, `is_active`
- **user_departments** (겸직)
  - `user_id`, `department_id`, `position_id`, `is_primary`

### 9.2 양식
- **approval_form_categories**
  - `id`, `parent_id`, `name`, `sort_order`
- **approval_forms**
  - `id`, `category_id`, `name`, `description`, `current_version`, `is_active`, `visibility_scope`(JSON: depts/positions)
- **approval_form_versions**
  - `id`, `form_id`, `version`, `schema`(JSONB), `created_by`, `created_at`
- **approval_line_templates** (자동결재선 규칙)
  - `id`, `form_id`(nullable=전역), `priority`, `condition`(JSONB), `line_template`(JSONB), `delegation_rules`(JSONB)

### 9.3 문서·결재선·단계
- **approval_documents**
  - `id`, `document_no`(채번), `form_id`, `form_version`, `title`, `drafter_id`, `drafter_department_id`, `payload`(JSONB), `status`(enum), `current_step_index`, `submitted_at`, `completed_at`
- **approval_steps**
  - `id`, `document_id`, `step_order`, `parallel_group`, `step_type`(결재/합의/협조/참조/공람), `approver_user_id`, `delegation_from_id`(대결/전결 출처), `status`(대기/승인/반려/대결/전결/보류/스킵), `acted_at`, `comment`, `signature_id`
- **approval_comments**
  - `id`, `document_id`, `user_id`, `body`, `created_at`
- **approval_attachments**
  - `id`, `document_id`, `file_path`(Storage), `file_name`, `mime`, `size`, `uploaded_by`
- **approval_audit_logs** (append-only)
  - `id`, `document_id`, `actor_id`, `action`, `payload`(JSONB), `ip`, `user_agent`, `created_at`

### 9.4 부재·위임
- **user_absences**
  - `id`, `user_id`, `start_at`, `end_at`, `delegate_user_id`, `scope`(JSON: form_ids or all), `reason`

### 9.5 서명/도장
- **user_signatures**
  - `id`, `user_id`, `type`(도장/서명), `storage_path`, `is_default`

---

## 10. 기술 스택 고려사항 (SvelteKit 2 + Svelte 5 + Supabase)

> 확정 스택: **Svelte 5 (runes) + SvelteKit 2 + `@supabase/ssr` + Supabase local**
> 라우팅·데이터 로딩·Form Actions 중심으로 서버 권한 재확인을 강제하고, 클라이언트는 Realtime과 낙관적 업데이트만 담당한다.

### 10.1 RLS 기반 권한
- `auth.uid()` 기준으로 *내가 볼 수 있는 문서*를 결정
- 한 문서는 **기안자 / 결재선 참여자 / 참조자 / 공람자 / 관리자** 각각 읽기 권한이 다름
- 단계별 뷰: `approval_document_viewers` 뷰 또는 `SECURITY DEFINER` 함수로 "내가 이 문서를 볼 수 있나" 결정
- 쓰기 RLS는 더 까다롭다: "현재 단계의 approver만 approve 가능" → step update policy에 `current_step_index`와 `approver_user_id=auth.uid()` 체크
- 부서 기반 권한은 **user_departments**를 JOIN하는 `SECURITY DEFINER` 함수(`is_in_department(dept_id)`)로 캐싱/단순화
- **SvelteKit 관점**: RLS는 1차 방어선이고, `+page.server.ts`의 `load`와 `actions` 진입 시 `locals.user` null 체크 + 역할 재확인으로 2차 방어선을 둔다

### 10.2 Realtime 알림 (Svelte 5 runes)
- `approval_steps` 테이블의 변경을 Realtime 구독 → 대상 사용자에게 실시간 팝업
- 클라이언트 필터: `approver_user_id=eq.{me}`
- Svelte 5에서는 `$state`로 알림 리스트를 선언하고 `$effect`에서 `supabase.channel(...).on('postgres_changes', ...)` 구독, `return () => channel.unsubscribe()`로 cleanup
- 브로드캐스트 최소화를 위해 서버 사이드 채널 혹은 Edge Function 트리거 사용

### 10.3 Storage (첨부/PDF)
- 버킷 분리: `approval-attachments` (기안 시 업로드), `approval-archives` (완료 후 PDF 보존)
- Storage RLS는 테이블 RLS와 동일 규칙 mirror 필요 → `path`에 `document_id/` prefix를 넣고 SELECT policy로 체크
- 대용량 업로드는 브라우저 → Signed Upload URL 직접 업로드(서버 경유 X)
- 완료 시 Edge Function에서 HTML → PDF(Puppeteer/Chromium) 변환 → `archives` 버킷에 저장 + 해시 기록

### 10.4 스케줄러 / 백그라운드
- **pg_cron**: 미처리 문서 리마인더, 부재 시작/종료 시 위임 전환, 장기 보관 정책
- **pg_net**: 외부 시스템 연동 webhook (회계/근태/ERP)
- **Edge Functions**: PDF 변환, 메일 발송, 외부 API 연동 허브

### 10.5 트랜잭션/정합성
- 결재 처리(승인 + step 진행 + 다음 approver 알림)는 **DB 함수**(plpgsql)로 원자적 처리 권장
- SvelteKit `actions`는 얇은 래퍼로만 유지: 입력 검증 → `supabase.rpc('approve_step', {...})` 호출 → `locals`에서 권한 재확인 → 성공 시 `fail()` 또는 `redirect()`
- 병렬결재는 `parallel_group` 전원 승인 완료 시 다음 단계 진행하는 체크 로직을 DB 함수 내부에서 수행
- 자동결재선 적용은 상신 시점에 **스냅샷** 으로 steps 테이블에 INSERT (양식 규칙 변경이 진행 중 문서에 영향 주면 안 됨)

### 10.6 SvelteKit 인증 게이트 (`hooks.server.ts` + `safeGetSession`)
- `@supabase/ssr`의 `createServerClient`를 `hooks.server.ts`의 `handle`에서 생성, `event.locals.supabase`에 주입
- 쿠키 핸들러는 `getAll` / `setAll` 패턴 사용 (개별 `get/set/remove`는 deprecated)
- 세션은 항상 `safeGetSession()` 헬퍼로 검증: 먼저 `auth.getSession()`으로 JWT를 꺼낸 뒤 `auth.getUser()`로 Supabase Auth 서버에 실제 검증 왕복 → 통과한 것만 `locals.session`/`locals.user`로 세팅
- 이유: `getSession()` 단독은 쿠키 값만 읽어 위·변조 검증이 없다. 결재 시스템은 **절대** 그 값을 신뢰해서는 안 됨
- `+layout.server.ts`에서 `locals.session`을 반환 → 클라이언트 `+layout.svelte`가 하이드레이션
- 보호 라우트(`/approval/**`, `/admin/**`)는 `hooks.server.ts`의 두 번째 `handle` 단계 혹은 해당 `+layout.server.ts`에서 `if (!locals.user) throw redirect(303, '/login')`

### 10.7 서버 load & Form Actions 원칙
- **조회**: `+page.server.ts`의 `load`에서 `locals.supabase`로 쿼리. 클라이언트에 service-role 키가 노출될 일이 원천 차단됨
- **결재 처리(승인/반려/회수/위임)**: 각 `+page.server.ts`의 `actions: { approve, reject, withdraw, delegate }`로 분리
- Form Actions 안에서 반드시 다음 순서를 지킬 것:
  1. `locals.user` 존재 확인
  2. `request.formData()` 검증 (Zod/Valibot)
  3. RLS가 걸린 `locals.supabase.rpc(...)` 호출
  4. 결과에 따라 `fail(400, {...})` 또는 `redirect(303, ...)`
- 결재 UI는 Progressive Enhancement(`use:enhance`)로 동작 — JS 꺼진 환경·모바일 웹뷰에서도 결재 처리 가능해야 함

### 10.8 SvelteKit 라우트 구조 제안
```
src/
├── hooks.server.ts                          # Supabase 서버 클라이언트 + safeGetSession + 보호 라우트
├── app.d.ts                                 # App.Locals { supabase, session, user, safeGetSession }
└── routes/
    ├── +layout.server.ts                    # locals.session 반환 → 하이드레이션
    ├── +layout.svelte                       # 공통 셸, 알림 구독
    ├── login/
    │   ├── +page.svelte
    │   └── +page.server.ts                  # actions: { default } 로그인
    ├── approval/
    │   ├── inbox/
    │   │   ├── +page.server.ts              # load: 대기/진행/완료/반려/임시/회수/수신/참조 탭별 쿼리
    │   │   └── +page.svelte
    │   ├── drafts/
    │   │   └── new/
    │   │       └── [formId]/
    │   │           ├── +page.server.ts      # load: 양식 스키마 + 조직도, actions: { save, submit }
    │   │           └── +page.svelte         # Svelte 5 runes 기반 동적 폼
    │   └── documents/
    │       └── [id]/
    │           ├── +page.server.ts          # load: 문서 + steps + attachments, actions: { approve, reject, withdraw, delegate, comment }
    │           └── +page.svelte             # 결재 패널 + Realtime 구독
    └── admin/
        ├── forms/
        │   ├── +page.server.ts              # 양식 목록
        │   ├── +page.svelte
        │   └── [id]/
        │       ├── +page.server.ts          # actions: { saveSchema, publish }
        │       └── +page.svelte             # Drag & Drop 빌더
        └── org/
            ├── +page.server.ts
            └── +page.svelte                 # 조직도 관리
```

- 모든 결재 관련 mutation은 `+page.server.ts`의 `actions`에만 존재 — API 라우트(`+server.ts`)는 Realtime broadcast 헬퍼나 webhook 엔드포인트에만 제한적으로 사용
- 페이지 컴포넌트는 Svelte 5 runes(`$state`, `$derived`, `$props`, `$effect`)로 작성, `form` prop으로 action 결과 수신

---

## 11. 리스크 & 오픈 이슈

### 11.1 구현 난이도
| 영역 | 난이도 | 이유 |
|---|---|---|
| 양식 빌더 + 수식 + 조건부 표시 | 상 | 사실상 소규모 로우코드 엔진. 버전 스냅샷까지 고려해야 함. |
| 자동결재선 규칙 엔진 | 상 | 우선순위/충돌/기안자 편집 허용 범위 설계 |
| 결재선 스냅샷 vs 라이브 | 상 | 진행 중 위임/부재/인사발령이 결재선에 끼치는 영향 처리 |
| 부서/직급 RLS | 중상 | 겸직·대결·관리자 권한 조합 복잡 |
| 병렬결재/합의 동시성 | 중 | race condition, 트랜잭션 필수 |
| PDF 변환 보존 | 중 | 폰트·한글·서명 이미지 품질 |
| 모바일 UX | 중 | 결재함/결재 처리는 기본 필수 |

### 11.2 법적 고려사항
- **전자문서법(법률 제17353호, 2020 개정)**: 요건 충족 시 서면과 동일 효력 → "열람 가능 + 원형 보존" 요건을 시스템이 보장해야 함.
- **전자서명법(2021.6.10 시행)**: 공인전자서명 제도 폐지, "실지 명의 확인 가능한 전자서명"이면 효력 인정. 단순 이미지 도장도 효력은 있으나, 감사/분쟁 대비 **본인 확인(로그인 세션 + 2차 인증)** + **감사 로그** 가 결정적.
- 결재 완료 문서는 **변조 불가능하게 보존**해야 함 (Hash/타임스탬프 + PDF 보존 권장).
- 3년 이상 보관 의무 문서(세무·인사) 존재 → **Retention Policy** 필요.
- 공공 시장 진입 시 **CSAP(클라우드 보안 인증)** 필수. 두레이가 확보한 이유. → 초기 진입은 민간 SMB로 한정하는 것이 현실적.

### 11.3 오픈 이슈 (확인 필요)
- WEHAGO 가격 체계 (결재 단독 vs 번들): **확인 필요**
- 카카오워크 유료 플랜 내 결재 기능 제한: **확인 필요**
- 두레이 온프레미스 제공 여부 및 조건: **확인 필요** (CSAP 전용 제공 가능성)
- 플로우 전자결재의 고급 기능(자동결재선/양식 빌더) 수준: **확인 필요**
- 조직도 import/export 표준 포맷 — 다른 그룹웨어에서 마이그레이션 수요 **확인 필요**

---

## 12. References

### 두레이(Dooray!)
- [Dooray 결재 서비스 소개](https://dooray.com/main/en/service/workflow/)
- [Dooray 가격](https://dooray.com/home/pricing/?lang=ko_KR)
- [서식 등록 결재선 (Dooray 도움말)](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/2996999276602263342)
- [공용 결재선 설정 (Dooray 도움말)](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/2987132321501649504)
- [Dooray 서식 관리](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/2987132790963427878)
- [Dooray 결재 처리 방법](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/2992757359088689875)
- [Dooray 전자결재로 활용하기](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/2962315842277494095)
- [Dooray 부서 결재](https://helpdesk.dooray.com/share/pages/9wWo-xwiR66BO5LGshgVTg/3105261571546866235)

### 다우오피스(Daouoffice)
- [다우오피스 전자결재 소개](https://care.daouoffice.co.kr/hc/ko/articles/12139456325657)
- [다우오피스 전자결재 양식 샘플](https://care.daouoffice.co.kr/hc/ko/categories/115000384554)
- [다우오피스 자동결재선 개요 PDF](https://daouoffice.com/cloud_guide/approval/auto_approval_guide.pdf)
- [다우오피스 양식 편집기 가이드 PDF](http://support.daouoffice.com/resources/view/do_guide/2016_1118_approval_guide02.pdf)
- [다우오피스 전자결재 사용법 블로그](https://blog.daouoffice.com/entry/다우오피스-전자결재-사용법-Feat-양식-샘플)
- [다우오피스 선결/전결 차이](https://care.daouoffice.co.kr/hc/ko/articles/115003831033)
- [다우오피스 가격](https://daouoffice.com/price.jsp)

### 더존 WEHAGO
- [WEHAGO 홈](https://www.wehago.com/landing/ko/home/)
- [WEHAGO 전자결재 앱](https://play.google.com/store/apps/details?id=com.douzone.android.eapprovals)
- [WEHAGO H (전용 클라우드) 소개](https://www.douzone.com/product/wehagoh.jsp)
- [더존 위하고 리뷰(korea-erp)](https://korea-erp.com/wehago/)
- [더존 위하고 주요 기능(techview 블로그)](https://reviewinsight.blog/2024/11/13/)

### 네이버웍스(NAVER WORKS)
- [네이버웍스 가격](https://naver.worksmobile.com/pricing/)
- [네이버웍스 결재 상품 안내](https://naver.worksmobile.com/whats-new/workplace-user-notice/product-policy-change/products/)
- [네이버웍스 결재선 가이드 블로그](https://naver.worksmobile.com/blog/hr_master_approval/)
- [네이버웍스 결재 양식 만들기 블로그](https://naver.worksmobile.com/blog/hr_master_approval_form_1/)
- [네이버웍스 그룹웨어 기능](https://naver.worksmobile.com/feature/integration/category/groupware/)
- [공공 네이버웍스 가격](https://gov-naverworks.com/gov-pricing/)

### 카카오워크(KakaoWork)
- [카카오워크 전자결재 가이드(GitBook)](https://kakaowork.gitbook.io/kakao-work/hr/approval)
- [카카오워크 기안 작성](https://kakaowork.gitbook.io/kakao-work/hr/approval/user/approval-submit)
- [카카오워크 전자결재 시작하기](https://kakaowork.gitbook.io/kakao-work/hr/approval/user/get-started)
- [카카오워크 전결 결재·보안 신규기능 블로그](https://blog.kakaowork.com/53)
- [카카오워크 모바일 기안 상신 오픈 블로그](https://blog.kakaowork.com/127)

### 플로우(Flow) / 마드라스체크
- [플로우 전자결재 서비스 시작하기](https://support.flow.team/ko/flow/16344475345305)
- [플로우 그룹웨어 기능 탑재 - 바이라인네트워크](https://byline.network/2025/04/2-250/)
- [플로우 올인원 협업 플랫폼 - 플래텀](https://platum.kr/archives/256241)
- [플로우 나무위키](https://namu.wiki/w/%ED%94%8C%EB%A1%9C%EC%9A%B0(%EB%B9%84%EC%A6%88%EB%8B%88%EC%8A%A4%20%EB%8F%84%EA%B5%AC))

### 온나라(공공)
- [온-나라 2.0 (가온아이)](https://www.kaoni.com/?page_id=19421)
- [온나라 서비스 위키백과](https://ko.wikipedia.org/wiki/%EC%98%A8-%EB%82%98%EB%9D%BC_%EC%84%9C%EB%B9%84%EC%8A%A4)
- [KDI 온-나라 문서시스템 자료](https://eiec.kdi.re.kr/policy/materialView.do?num=176270)
- [정부 웹표준 전자결재시스템 확산 - ZDNet](https://zdnet.co.kr/view/?no=20180426180413)

### 결재 용어·개념
- [프릭스 - 헷갈리는 결재 용어 정리](https://www.prix.im/blog/posts/confusing-approval-terms-guide)
- [결재 - 나무위키](https://namu.wiki/w/%EA%B2%B0%EC%9E%AC)
- [결재 용어 총정리 (ihee)](https://www.ihee.com/621)
- [메일플러그 - 전자결재 용어와 옵션](https://www.mailplug-help.com/820678ae-0e94-4f09-b2b6-ba141d703a34)
- [한비로 그룹웨어 결재 구성메뉴](https://www.hanbiro.com/software/groupware-workflow-approval.html)
- [비즈메카 전자결재 도움말](https://ezportal.bizmeka.com/help/ko/gw-docs/PRO_000147.html)
- [하이웍스 전자결재 기능](https://biz-solution.hiworks.com/product/function/groupware/approval)

### 자동결재선 / 규칙
- [비즈플레이 - 회사규정 자동결재선 설정](https://docs.bizplay.co.kr/about-bizplay/tips/tip-0005)
- [가비아 하이웍스 기본/결재선 설정](https://customer.gabia.com/manual/hiworks/159/3921)
- [유니포스트 전자결재](https://unipost.co.kr/portal/unicloud/introduction/portalApprovalIntroduction)

### 법적 근거
- [전자서명법 (국가법령정보센터)](https://law.go.kr/%EB%B2%95%EB%A0%B9/%EC%A0%84%EC%9E%90%EC%84%9C%EB%AA%85%EB%B2%95)
- [모두싸인 - 전자문서법 개정 해설](https://blog.modusign.co.kr/insight/electronic_document_law)
- [이폼사인 - 전자서명·전자문서 법적 효력](https://www.eformsign.com/kr/blog/%EC%A0%84%EC%9E%90%EC%84%9C%EB%AA%85-%EC%A0%84%EC%9E%90%EB%AC%B8%EC%84%9C-%EB%B2%95%EC%A0%81%ED%9A%A8%EB%A0%A5/)
- [전자문서통합지원센터 - 전자문서 법적효력](https://www.npost.kr/front/eIntro/legEffect.do)
- [법제처 - 전자서명 법적 효력 해석](https://moleg.go.kr/lawinfo/lawAnalysis/nwLwAnList?csSeq=108482&rowIdx=2339)

### 양식/서식 레퍼런스
- [잡코리아 - 회사 문서 종류 소개](https://www.jobkorea.co.kr/goodjob/tip/view?News_No=19012)
- [캐스팅엔 - 기안서/품의서/지출결의서 차이](https://info.workmarket9.com/blog/document-process)
- [예스폼 - 품의서/기안서/공문 차이](https://blog.yesform.com/entry/품의서-기안서-공문-더-이상-헷갈리지-마세요)
- [예스폼 - 지출결의서 가이드](https://www.yesform.com/cnts_thmf/지출결의서+가이드-94/)

### Supabase
- [Supabase Row Level Security 공식 문서](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase AI Prompt - RLS Policies](https://supabase.com/docs/guides/getting-started/ai-prompts/database-rls-policies)
