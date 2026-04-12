import type { RequestHandler } from './$types';
import { error } from '@sveltejs/kit';
import { renderDocumentPdf } from '$lib/server/pdf/renderDocument';

export const GET: RequestHandler = async (event) => {
	const { locals, params, url, fetch } = event;
	if (!locals.user) error(401);

	const { data: doc } = await locals.supabase
		.from('approval_documents')
		.select('id, doc_number, tenant_id')
		.eq('id', params.id)
		.maybeSingle();

	if (!doc) error(404);

	// event.fetch — SvelteKit 내부 fetch로 세션 쿠키 자동 공유
	const printUrl =
		`/t/${params.tenantSlug}/approval/documents/${params.id}?print=1`;
	const htmlRes = await fetch(printUrl);

	if (!htmlRes.ok) {
		console.error('[pdf] print page fetch failed:', htmlRes.status);
		error(503, 'PDF 생성 실패 — print 페이지 로드 오류');
	}

	const html = await htmlRes.text();

	let pdf: Uint8Array;
	try {
		pdf = await renderDocumentPdf({
			html,
			baseUrl: url.origin
		});
	} catch (err) {
		console.error('[pdf] renderDocumentPdf failed:', err);
		error(503, 'PDF 생성 실패');
	}

	return new Response(new Uint8Array(pdf), {
		headers: {
			'Content-Type': 'application/pdf',
			'Content-Disposition': `inline; filename="${doc.doc_number}.pdf"`,
			'Cache-Control': 'no-store'
		}
	});
};
