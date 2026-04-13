-- 초과근무 신청 양식 seed (기존 approval_forms 활용)
INSERT INTO public.approval_forms (tenant_id, code, name, schema, is_published)
SELECT
  t.id,
  'overtime',
  '초과근무 신청',
  '{
    "fields": [
      {"key": "overtime_date", "label": "근무일", "type": "date", "required": true},
      {"key": "hours", "label": "초과근무 시간(h)", "type": "number", "required": true},
      {"key": "reason", "label": "사유", "type": "textarea", "required": true}
    ]
  }'::jsonb,
  true
FROM public.tenants t
WHERE NOT EXISTS (
  SELECT 1 FROM public.approval_forms af
  WHERE af.tenant_id = t.id AND af.code = 'overtime'
);
