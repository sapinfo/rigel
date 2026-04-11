import { browser } from '$app/environment';
import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Client-side attachment upload.
 * Storage path: {tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}
 * Original filename is stored in approval_attachments.file_name only.
 */

function extractExt(fileName: string): string {
  const match = /\.([a-zA-Z0-9]{1,10})$/.exec(fileName);
  return match ? match[1].toLowerCase() : 'bin';
}

function currentMonthKST(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit'
  }).format(new Date());
}

export type UploadedAttachment = {
  id: string;
  fileName: string;
  size: number;
  mime: string;
};

export async function uploadAttachment(
  tenantId: string,
  file: File
): Promise<UploadedAttachment> {
  if (!browser) throw new Error('Client only');

  const supabase = createBrowserClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY
  );

  const uploadUuid = crypto.randomUUID();
  const ext = extractExt(file.name);
  const month = currentMonthKST();
  const storagePath = `${tenantId}/${month}/${uploadUuid}.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('approval-attachments')
    .upload(storagePath, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type || 'application/octet-stream'
    });
  if (upErr) throw upErr;

  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    await supabase.storage.from('approval-attachments').remove([storagePath]);
    throw new Error('Not authenticated');
  }

  const { data: row, error: insErr } = await supabase
    .from('approval_attachments')
    .insert({
      tenant_id: tenantId,
      storage_path: storagePath,
      file_name: file.name,
      mime: file.type || 'application/octet-stream',
      size: file.size,
      uploaded_by: user.id,
      document_id: null
    })
    .select('id')
    .single();

  if (insErr || !row) {
    await supabase.storage.from('approval-attachments').remove([storagePath]);
    throw insErr ?? new Error('Attachment insert failed');
  }

  return {
    id: row.id as string,
    fileName: file.name,
    size: file.size,
    mime: file.type || 'application/octet-stream'
  };
}
