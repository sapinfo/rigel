-- groupware-attachments 버킷 (게시판/공지 첨부파일용)
INSERT INTO storage.buckets (id, name, public)
VALUES ('groupware-attachments', 'groupware-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS
CREATE POLICY groupware_attachments_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'groupware-attachments');

CREATE POLICY groupware_attachments_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'groupware-attachments');

CREATE POLICY groupware_attachments_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'groupware-attachments');
