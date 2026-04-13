-- 0058_board_comments.sql
-- 댓글 + RLS

CREATE TABLE public.board_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.board_posts(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id),
  content text NOT NULL CHECK (length(content) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX board_comments_post_idx ON public.board_comments (post_id, created_at);

ALTER TABLE public.board_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY board_comments_select ON public.board_comments
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY board_comments_insert ON public.board_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_tenant_member(tenant_id)
    AND author_id = (SELECT auth.uid())
  );

CREATE POLICY board_comments_delete ON public.board_comments
  FOR DELETE TO authenticated
  USING (
    author_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
