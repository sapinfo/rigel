-- 0057_board_posts.sql
-- 게시글 + 조회수 RPC + RLS

CREATE TABLE public.board_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id uuid NOT NULL REFERENCES public.boards(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  content jsonb NOT NULL DEFAULT '{}',
  author_id uuid NOT NULL REFERENCES auth.users(id),
  is_pinned boolean NOT NULL DEFAULT false,
  view_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX board_posts_board_idx ON public.board_posts (board_id, is_pinned DESC, created_at DESC);
CREATE INDEX board_posts_tenant_idx ON public.board_posts (tenant_id);

ALTER TABLE public.board_posts ENABLE ROW LEVEL SECURITY;

-- board 접근 체크 헬퍼 (양방향 RLS 재귀 방지)
CREATE OR REPLACE FUNCTION public.can_access_board(p_board_id uuid)
  RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.boards b
    WHERE b.id = p_board_id
    AND public.is_tenant_member(b.tenant_id)
    AND (
      b.board_type = 'general'
      OR b.department_id IN (
        SELECT ud.department_id FROM public.user_departments ud
        WHERE ud.user_id = auth.uid() AND ud.tenant_id = b.tenant_id
      )
    )
  );
$$;

CREATE POLICY board_posts_select ON public.board_posts
  FOR SELECT TO authenticated
  USING (public.can_access_board(board_id));

CREATE POLICY board_posts_insert ON public.board_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    public.can_access_board(board_id)
    AND author_id = (SELECT auth.uid())
  );

CREATE POLICY board_posts_update ON public.board_posts
  FOR UPDATE TO authenticated
  USING (
    author_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

CREATE POLICY board_posts_delete ON public.board_posts
  FOR DELETE TO authenticated
  USING (
    author_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

-- 조회수 증가 RPC
CREATE OR REPLACE FUNCTION public.increment_post_view(p_post_id uuid)
  RETURNS void
  LANGUAGE sql SECURITY DEFINER
  SET search_path = public
AS $$
  UPDATE public.board_posts
  SET view_count = view_count + 1
  WHERE id = p_post_id;
$$;
