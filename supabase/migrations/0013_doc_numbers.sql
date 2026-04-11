-- 0013_doc_numbers.sql
-- 테넌트별 일자별 문서 번호 시퀀스.
-- 포맷: APP-{YYYYMMDD}-{4-digit-seq}
-- 원자성: INSERT ... ON CONFLICT DO UPDATE SET last_seq = last_seq + 1

CREATE TABLE public.doc_number_sequences (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  day date NOT NULL,
  last_seq int NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, day)
);

-- 직접 접근 전면 차단. fn_next_doc_number(SECURITY DEFINER) 경유만.
ALTER TABLE public.doc_number_sequences ENABLE ROW LEVEL SECURITY;
-- 정책 없음 = 암묵적 거부

-- ─── fn_next_doc_number ──────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_next_doc_number(p_tenant_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  v_seq int;
BEGIN
  INSERT INTO public.doc_number_sequences (tenant_id, day, last_seq)
  VALUES (p_tenant_id, v_day, 1)
  ON CONFLICT (tenant_id, day)
  DO UPDATE SET last_seq = public.doc_number_sequences.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'APP-' || to_char(v_day, 'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
END;
$$;

-- 공개 실행 금지 — RPC 내부에서만 호출
-- authenticated role에 GRANT 하지 않음
