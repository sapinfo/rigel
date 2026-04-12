-- 0038_notifications.sql
-- v1.3 M19: notifications 테이블 + RLS + trigger fn_create_notification + 3 RPCs
-- Design: §3.2, §5.1, §6

BEGIN;

-- ─── 1. notification_type enum ──────────────────────────────
CREATE TYPE public.notification_type AS ENUM (
  'approval_requested',
  'approved',
  'rejected',
  'commented',
  'withdrawn'
);

-- ─── 2. notifications 테이블 ────────────────────────────────
CREATE TABLE public.notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid        NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id      uuid        NOT NULL,
  document_id  uuid        NOT NULL REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  type         public.notification_type NOT NULL,
  title        text        NOT NULL,
  body         text,
  read         boolean     NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notifications IS
  'v1.3: 인앱 + 이메일 알림. fn_create_notification trigger가 audit_logs INSERT 후 자동 생성.';

-- ─── 3. 인덱스 ─────────────────────────────────────────────
CREATE INDEX notifications_user_unread_idx
  ON public.notifications (user_id, read, created_at DESC)
  WHERE read = false;

CREATE INDEX notifications_user_created_idx
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX notifications_document_idx
  ON public.notifications (document_id);

-- ─── 4. RLS ─────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
  ON public.notifications FOR SELECT
  USING (user_id = (SELECT auth.uid()));

-- INSERT/UPDATE 정책 없음 → SECURITY DEFINER 함수만 write 가능

GRANT SELECT ON public.notifications TO authenticated;

-- ─── 5. fn_notify_email_async stub (pg_net 없이도 trigger 컴파일 가능) ─
CREATE OR REPLACE FUNCTION public.fn_notify_email_async(
  p_document_id uuid,
  p_tenant_id   uuid,
  p_action      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 0039에서 pg_net 호출로 교체
  NULL;
END;
$$;

-- ─── 6. fn_create_notification (trigger function) ───────────
CREATE OR REPLACE FUNCTION public.fn_create_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc       public.approval_documents;
  v_action    text := NEW.action::text;
  v_doc_id    uuid := NEW.document_id;
  v_tenant_id uuid;
  v_actor_id  uuid := NEW.actor_id;
  v_current_group int;
  v_notif_type public.notification_type;
  v_title     text;
  v_body      text;
  v_doc_title text;
  r           record;
BEGIN
  -- 알림 불필요 액션
  IF v_action IN ('draft_saved', 'delegated', 'auto_delegated', 'submitted_post_facto') THEN
    RETURN NEW;
  END IF;

  -- 문서 조회
  SELECT * INTO v_doc
    FROM public.approval_documents
   WHERE id = v_doc_id;

  IF v_doc.id IS NULL THEN
    RETURN NEW;
  END IF;

  v_tenant_id   := v_doc.tenant_id;
  v_current_group := v_doc.current_step_index;

  -- 문서 제목: form title → doc_number fallback
  v_doc_title := coalesce(v_doc.form_schema_snapshot->>'title', v_doc.doc_number);

  -- ── 액션별 수신자 + 알림 유형 결정 ──────────────────────────────

  IF v_action = 'submit' THEN
    v_notif_type := 'approval_requested';
    v_title      := format('[결재 요청] %s', v_doc_title);
    v_body       := '결재를 요청했습니다.';

    FOR r IN
      SELECT approver_user_id
        FROM public.approval_steps
       WHERE document_id = v_doc_id
         AND group_order  = v_current_group
         AND step_type    = 'approval'
         AND status       = 'pending'
    LOOP
      INSERT INTO public.notifications
        (tenant_id, user_id, document_id, type, title, body)
      VALUES
        (v_tenant_id, r.approver_user_id, v_doc_id, v_notif_type, v_title, v_body);
    END LOOP;

  ELSIF v_action IN ('approve', 'approved_by_proxy') THEN
    IF v_doc.status = 'completed' THEN
      -- 최종 승인 → 기안자에게 완료 알림
      v_notif_type := 'approved';
      v_title      := format('[결재 완료] %s', v_doc_title);
      v_body       := '문서가 최종 승인되었습니다.';
      INSERT INTO public.notifications
        (tenant_id, user_id, document_id, type, title, body)
      VALUES
        (v_tenant_id, v_doc.drafter_id, v_doc_id, v_notif_type, v_title, v_body);
    ELSE
      -- 다음 그룹 결재자에게 결재 요청
      v_notif_type := 'approval_requested';
      v_title      := format('[결재 요청] %s', v_doc_title);
      v_body       := '이전 결재자가 승인하였습니다. 결재를 진행해 주세요.';

      FOR r IN
        SELECT approver_user_id
          FROM public.approval_steps
         WHERE document_id = v_doc_id
           AND group_order  = v_current_group
           AND step_type    = 'approval'
           AND status       = 'pending'
      LOOP
        INSERT INTO public.notifications
          (tenant_id, user_id, document_id, type, title, body)
        VALUES
          (v_tenant_id, r.approver_user_id, v_doc_id, v_notif_type, v_title, v_body);
      END LOOP;
    END IF;

  ELSIF v_action = 'reject' THEN
    v_notif_type := 'rejected';
    v_title      := format('[반려] %s', v_doc_title);
    v_body       := '문서가 반려되었습니다.';
    INSERT INTO public.notifications
      (tenant_id, user_id, document_id, type, title, body)
    VALUES
      (v_tenant_id, v_doc.drafter_id, v_doc_id, v_notif_type, v_title, v_body);

  ELSIF v_action = 'comment' THEN
    v_notif_type := 'commented';
    v_title      := format('[코멘트] %s', v_doc_title);
    v_body       := '새 코멘트가 등록되었습니다.';

    -- 기안자 (액터 본인이 아닌 경우)
    IF v_doc.drafter_id <> v_actor_id THEN
      INSERT INTO public.notifications
        (tenant_id, user_id, document_id, type, title, body)
      VALUES
        (v_tenant_id, v_doc.drafter_id, v_doc_id, v_notif_type, v_title, v_body);
    END IF;

    -- 모든 approval step 담당자 (중복 + 액터 + 기안자 제외)
    FOR r IN
      SELECT DISTINCT approver_user_id
        FROM public.approval_steps
       WHERE document_id = v_doc_id
         AND step_type   = 'approval'
         AND approver_user_id <> v_actor_id
         AND approver_user_id <> v_doc.drafter_id
    LOOP
      INSERT INTO public.notifications
        (tenant_id, user_id, document_id, type, title, body)
      VALUES
        (v_tenant_id, r.approver_user_id, v_doc_id, v_notif_type, v_title, v_body);
    END LOOP;

  ELSIF v_action = 'withdraw' THEN
    v_notif_type := 'withdrawn';
    v_title      := format('[회수] %s', v_doc_title);
    v_body       := '기안자가 문서를 회수하였습니다.';

    FOR r IN
      SELECT approver_user_id
        FROM public.approval_steps
       WHERE document_id = v_doc_id
         AND group_order  = v_current_group
         AND step_type    = 'approval'
         AND status       = 'pending'
    LOOP
      INSERT INTO public.notifications
        (tenant_id, user_id, document_id, type, title, body)
      VALUES
        (v_tenant_id, r.approver_user_id, v_doc_id, v_notif_type, v_title, v_body);
    END LOOP;
  END IF;

  -- pg_net Edge Function 호출 (stub → 0039에서 실체화)
  PERFORM public.fn_notify_email_async(v_doc_id, v_tenant_id, v_action);

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- 알림 실패가 결재 흐름을 막으면 안 됨
  RAISE WARNING 'fn_create_notification error: % %', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

-- ─── 7. Trigger ─────────────────────────────────────────────
CREATE TRIGGER trg_create_notification
  AFTER INSERT ON public.approval_audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_create_notification();

-- ─── 8. RPC: mark_notification_read ─────────────────────────
CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.notifications
     SET read = true
   WHERE id      = p_notification_id
     AND user_id = (SELECT auth.uid())
     AND read    = false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

-- ─── 9. RPC: mark_all_notifications_read ────────────────────
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(
  p_tenant_id uuid
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.notifications
     SET read = true
   WHERE user_id   = (SELECT auth.uid())
     AND tenant_id = p_tenant_id
     AND read      = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) TO authenticated;

-- ─── 10. RPC: get_notifications ─────────────────────────────
CREATE OR REPLACE FUNCTION public.get_notifications(
  p_tenant_id uuid,
  p_limit     int DEFAULT 20,
  p_offset    int DEFAULT 0
)
RETURNS TABLE (
  id          uuid,
  document_id uuid,
  type        public.notification_type,
  title       text,
  body        text,
  read        boolean,
  created_at  timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT n.id, n.document_id, n.type, n.title, n.body, n.read, n.created_at
      FROM public.notifications n
     WHERE n.user_id   = (SELECT auth.uid())
       AND n.tenant_id = p_tenant_id
     ORDER BY n.created_at DESC
     LIMIT  p_limit
     OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_notifications(uuid, int, int) TO authenticated;

COMMIT;
