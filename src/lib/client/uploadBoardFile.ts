import { browser } from '$app/environment';
import { createRigelBrowserClient } from '$lib/client/supabase';

/**
 * Client-side file upload for boards / announcements.
 * Bucket: groupware-attachments
 * Path: {tenant_id}/{type}/{YYYY-MM}/{uuid}.{ext}
 * Original filename stored in board_attachments.file_name.
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

export type UploadedBoardFile = {
  id: string;
  fileName: string;
  size: number;
  mime: string;
};

export async function uploadBoardFile(
  tenantId: string,
  file: File,
  type: 'boards' | 'announcements'
): Promise<UploadedBoardFile> {
  if (!browser) throw new Error('Client only');

  const supabase = createRigelBrowserClient();

  const uploadUuid = crypto.randomUUID();
  const ext = extractExt(file.name);
  const month = currentMonthKST();
  const storagePath = `${tenantId}/${type}/${month}/${uploadUuid}.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('groupware-attachments')
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
    await supabase.storage.from('groupware-attachments').remove([storagePath]);
    throw new Error('Not authenticated');
  }

  const { data: row, error: insErr } = await supabase
    .from('board_attachments')
    .insert({
      tenant_id: tenantId,
      storage_path: storagePath,
      file_name: file.name,
      mime: file.type || 'application/octet-stream',
      size: file.size,
      uploaded_by: user.id
    })
    .select('id')
    .single();

  if (insErr || !row) {
    await supabase.storage.from('groupware-attachments').remove([storagePath]);
    throw insErr ?? new Error('Attachment insert failed');
  }

  return {
    id: row.id as string,
    fileName: file.name,
    size: file.size,
    mime: file.type || 'application/octet-stream'
  };
}
