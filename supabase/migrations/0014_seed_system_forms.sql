-- 0014_seed_system_forms.sql
-- 시스템 양식 5종 시드. tenant_id IS NULL, is_published = true.
-- fn_create_tenant → fn_copy_system_forms(SECURITY DEFINER)가 테넌트 생성 시 복사.

INSERT INTO public.approval_forms (
  tenant_id, code, name, description, schema, default_approval_line, is_published
) VALUES
-- 1. 일반 기안서
(NULL, 'general', '일반 기안서', '일반적인 업무 기안',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "placeholder": "기안 제목을 입력하세요", "maxLength": 200},
     {"id": "summary", "type": "textarea", "label": "요약", "required": true, "maxLength": 500},
     {"id": "body", "type": "textarea", "label": "내용", "required": true},
     {"id": "attachments", "type": "attachment", "label": "첨부파일", "maxFiles": 5, "maxSizeBytes": 10485760}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 2. 휴가신청서
(NULL, 'leave-request', '휴가신청서', '연차·반차·경조사 휴가 신청',
 '{
   "version": 1,
   "fields": [
     {"id": "leave_type", "type": "select", "label": "휴가 종류", "required": true,
      "options": [
        {"value": "annual", "label": "연차"},
        {"value": "half", "label": "반차"},
        {"value": "sick", "label": "병가"},
        {"value": "family", "label": "경조사"},
        {"value": "unpaid", "label": "무급휴가"}
      ]},
     {"id": "period", "type": "date-range", "label": "휴가 기간", "required": true},
     {"id": "reason", "type": "textarea", "label": "사유", "required": true, "maxLength": 500},
     {"id": "contact", "type": "text", "label": "비상 연락처", "required": false}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 3. 지출결의서
(NULL, 'expense-report', '지출결의서', '법인카드·경비 지출 정산',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "maxLength": 200},
     {"id": "expense_date", "type": "date", "label": "지출일", "required": true},
     {"id": "amount", "type": "number", "label": "금액", "required": true, "min": 0, "unit": "원"},
     {"id": "category", "type": "select", "label": "비용 항목", "required": true,
      "options": [
        {"value": "meal", "label": "식대"},
        {"value": "transport", "label": "교통비"},
        {"value": "supplies", "label": "비품"},
        {"value": "entertainment", "label": "접대비"},
        {"value": "other", "label": "기타"}
      ]},
     {"id": "description", "type": "textarea", "label": "사용 내역", "required": true},
     {"id": "receipts", "type": "attachment", "label": "영수증", "required": true, "maxFiles": 10, "accept": "image/*,application/pdf"}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 4. 품의서
(NULL, 'proposal', '품의서', '지출 전 승인이 필요한 품의',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "품의 제목", "required": true, "maxLength": 200},
     {"id": "purpose", "type": "textarea", "label": "품의 목적", "required": true},
     {"id": "budget", "type": "number", "label": "예산", "required": true, "min": 0, "unit": "원"},
     {"id": "justification", "type": "textarea", "label": "타당성", "required": true},
     {"id": "attachments", "type": "attachment", "label": "근거 자료", "maxFiles": 10}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 5. 업무협조전
(NULL, 'cooperation', '업무협조전', '타 부서에 업무 협조 요청',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "maxLength": 200},
     {"id": "target_department", "type": "text", "label": "협조 요청 부서", "required": true},
     {"id": "deadline", "type": "date", "label": "요청 완료일"},
     {"id": "content", "type": "textarea", "label": "협조 요청 내용", "required": true},
     {"id": "attachments", "type": "attachment", "label": "첨부파일", "maxFiles": 5}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true);
