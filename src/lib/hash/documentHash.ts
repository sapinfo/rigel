// src/lib/hash/documentHash.ts
// v1.2: content_hash 계산. 클라이언트·서버 양쪽 호환 (Web Crypto API).
//
// 입력 스키마:
//   - formSchema: 양식 JSON 스키마 (snapshot)
//   - content: 사용자 입력 본문
//   - approvalLine: 결재선 (userId, stepType, groupOrder)
//   - attachmentSha256s: 첨부 파일별 SHA-256 (계산 전 정렬)
//
// 출력: 64자 hex SHA-256
//
// 입력 정규화 규칙:
//   1. approvalLine item 의 groupOrder 가 undefined 일 경우 null 로 통일
//      (JCS 는 undefined 를 금지하므로 명시적으로 null 변환)
//   2. approvalLine 자체는 순서 유지 (사용자가 지정한 결재선 순서가 의미 있음)
//   3. attachmentSha256s 는 정렬 — 업로드 순서에 의존하지 않음

import { canonicalize } from './jcs';
import type { FormSchema, ApprovalLineItem } from '$lib/types/approval';

export interface DocumentHashInput {
  formSchema: FormSchema;
  content: Record<string, unknown>;
  approvalLine: ApprovalLineItem[];
  attachmentSha256s: string[];
}

export async function computeDocumentHash(input: DocumentHashInput): Promise<string> {
  const normalized = {
    schema: input.formSchema as unknown as Record<string, unknown>,
    content: input.content,
    line: input.approvalLine.map((i) => ({
      userId: i.userId,
      stepType: i.stepType,
      groupOrder: i.groupOrder ?? null
    })),
    // 정렬된 attachment hash 배열 (원본 불변)
    attachments: [...input.attachmentSha256s].sort()
  };
  const canonical = canonicalize(normalized);
  return sha256Hex(canonical);
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const arr = new Uint8Array(digest);
  let out = '';
  for (const b of arr) {
    out += b.toString(16).padStart(2, '0');
  }
  return out;
}
