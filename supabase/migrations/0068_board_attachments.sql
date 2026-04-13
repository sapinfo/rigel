CREATE TABLE public.board_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  post_id uuid REFERENCES public.board_posts(id) ON DELETE SET NULL,
  announcement_id uuid REFERENCES public.announcements(id) ON DELETE SET NULL,
  storage_path text NOT NULL,
  file_name text NOT NULL,
  mime text NOT NULL DEFAULT 'application/octet-stream',
  size integer NOT NULL DEFAULT 0,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (post_id IS NOT NULL AND announcement_id IS NULL)
    OR (post_id IS NULL AND announcement_id IS NOT NULL)
    OR (post_id IS NULL AND announcement_id IS NULL)
  )
);

ALTER TABLE public.board_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY board_attachments_select ON public.board_attachments
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY board_attachments_insert ON public.board_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
  );

CREATE POLICY board_attachments_delete ON public.board_attachments
  FOR DELETE TO authenticated
  USING (
    uploaded_by = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
