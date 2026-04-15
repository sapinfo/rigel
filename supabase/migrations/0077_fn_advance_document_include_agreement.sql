-- 0077_fn_advance_document_include_agreement.sql
--
-- Bug fix: 같은 그룹에 [approval + agreement] 가 있을 때 approval 만 승인되면
-- agreement pending 을 남긴 채 다음 그룹으로 advance 됨. 결과적으로 합의자가
-- 액션을 취하기도 전에 다음 단계 결재자 inbox 에 문서가 뜸.
--
-- 재현 (2026-04-15):
--   결재선: group 0 [김과장 결재, 최과장 합의], group 1 [김부장 결재]
--   김과장 승인 → 문서 current_step_index 가 1 로 점프 → 김부장 대기 탭에 노출
--   최과장은 합의 pending 인 채로 flow 바깥에 고립
--
-- 원인:
--   fn_advance_document 의 "현재 그룹 미완 판정" 쿼리가 step_type = 'approval'
--   만 보고 'agreement' 를 누락. approve/agree 후 호출될 때 같은 그룹의 미처리
--   합의를 고려하지 않음.
--
-- 수정:
--   step_type IN ('approval', 'agreement') 로 확장. reference 는 기존대로
--   조건 바깥 — 참조는 action 없이 approval 완료 시 자동 skipped 되는 설계
--   (0031 v1 의 Risk #13 재현 로직).
--
-- 다음 그룹 탐색 (group_order > current) 은 그대로 approval 기준 유지.
-- UI 가 합의를 항상 approval 과 같은 그룹에 강제하므로 approval 있는 그룹만
-- 순회해도 합의 도달 누락 없음.
--
-- 회귀 안전성:
--   - 기존 순수 approval 결재선 동작 변화 없음 (agreement 0건)
--   - 병렬 approval 그룹 동작 변화 없음
--   - 반려/회수/후결 경로 영향 없음 (이 함수는 성공 경로만)

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_advance_document(p_document_id uuid)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc public.approval_documents;
  v_current_group int;
  v_has_pending boolean;
  v_next_group int;
BEGIN
  SELECT * INTO v_doc
    FROM public.approval_documents
   WHERE id = p_document_id
   FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found: %', p_document_id USING ERRCODE = '02000';
  END IF;

  -- 종결 상태면 변경 없이 반환 (멱등)
  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RETURN v_doc;
  END IF;

  v_current_group := v_doc.current_step_index;

  -- 현재 group 내 pending approval OR agreement step 있는지 (v6 수정)
  SELECT EXISTS (
    SELECT 1
      FROM public.approval_steps
     WHERE document_id = p_document_id
       AND group_order = v_current_group
       AND step_type IN ('approval', 'agreement')
       AND status = 'pending'
  ) INTO v_has_pending;

  IF v_has_pending THEN
    RETURN v_doc;  -- 그룹 미완
  END IF;

  -- 다음 pending approval group 탐색 (기준 유지: approval 기반)
  SELECT MIN(group_order) INTO v_next_group
    FROM public.approval_steps
   WHERE document_id = p_document_id
     AND group_order > v_current_group
     AND step_type = 'approval'
     AND status = 'pending';

  IF v_next_group IS NULL THEN
    -- 모든 approval 완료 → document completed
    -- Risk #13 재현: 남은 pending reference/agreement step 일괄 skipped
    UPDATE public.approval_steps
       SET status = 'skipped'
     WHERE document_id = p_document_id
       AND status = 'pending';

    UPDATE public.approval_documents
       SET status = 'completed',
           completed_at = now(),
           updated_at = now()
     WHERE id = p_document_id
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
       SET current_step_index = v_next_group,
           updated_at = now()
     WHERE id = p_document_id
    RETURNING * INTO v_doc;
  END IF;

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_advance_document(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_advance_document(uuid) IS
  'v2.2 fix: group 완료 판정에 agreement 포함. 0031 v1 에서 approval 만 체크하던 버그 수정 — 같은 그룹의 agreement pending 고립 방지.';

COMMIT;
