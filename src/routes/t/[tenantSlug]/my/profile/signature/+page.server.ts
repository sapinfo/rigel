import { error, fail } from '@sveltejs/kit';
import { createHash } from 'node:crypto';
import type { Actions, PageServerLoad } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';

async function resolveTenant(
	supabase: SupabaseClient,
	userId: string,
	slug: string
): Promise<{ id: string; slug: string } | null> {
	const { data } = await supabase
		.from('tenant_members')
		.select('tenant:tenants!inner(id, slug)')
		.eq('user_id', userId)
		.eq('tenant.slug', slug)
		.maybeSingle();
	if (!data) return null;
	const t = data.tenant as unknown as { id: string; slug: string };
	return { id: t.id, slug: t.slug };
}

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { currentTenant } = await parent();
	if (!currentTenant) error(404);

	const userId = locals.user!.id;

	const { data: profile } = await locals.supabase
		.from('profiles')
		.select('signature_storage_path')
		.eq('id', userId)
		.maybeSingle();

	let currentSignatureUrl: string | null = null;
	const path = profile?.signature_storage_path as string | null;
	if (path) {
		const { data: signed } = await locals.supabase.storage
			.from('user-signatures')
			.createSignedUrl(path, 120);
		currentSignatureUrl = signed?.signedUrl ?? null;
	}

	return { currentSignatureUrl };
};

const PNG_MAGIC = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
const MAX_SIZE = 512 * 1024; // 512KB

export const actions: Actions = {
	default: async ({ request, locals, params }) => {
		if (!locals.user) return fail(401);
		const currentTenant = await resolveTenant(locals.supabase, locals.user.id, params.tenantSlug);
		if (!currentTenant) return fail(404);

		const userId = locals.user!.id;
		const fd = await request.formData();
		const file = fd.get('signature');

		if (!(file instanceof File) || file.size === 0) {
			return fail(400, { actionError: '파일을 선택해 주세요' });
		}

		if (file.size > MAX_SIZE) {
			return fail(400, { actionError: '파일 크기 512KB 초과' });
		}

		const buf = new Uint8Array(await file.arrayBuffer());

		// PNG magic bytes validation
		if (buf.length < 4 || buf[0] !== PNG_MAGIC[0] || buf[1] !== PNG_MAGIC[1] || buf[2] !== PNG_MAGIC[2] || buf[3] !== PNG_MAGIC[3]) {
			return fail(400, { actionError: '유효한 PNG 파일이 아닙니다' });
		}

		const sha256 = createHash('sha256').update(buf).digest('hex');
		const storagePath = `${userId}/signature.png`;

		// Storage upsert
		const { error: uploadErr } = await locals.supabase.storage
			.from('user-signatures')
			.upload(storagePath, buf, {
				contentType: 'image/png',
				upsert: true
			});

		if (uploadErr) {
			return fail(500, { actionError: '업로드 실패: ' + uploadErr.message });
		}

		// Profile update
		const { error: updateErr } = await locals.supabase
			.from('profiles')
			.update({
				signature_storage_path: storagePath,
				signature_sha256: sha256
			})
			.eq('id', userId);

		if (updateErr) {
			return fail(500, { actionError: '프로필 업데이트 실패' });
		}

		return { ok: true };
	}
};
