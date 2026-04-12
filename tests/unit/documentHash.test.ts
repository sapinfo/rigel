import { describe, it, expect } from 'vitest';
import { computeDocumentHash } from '../../src/lib/hash/documentHash';
import type { FormSchema, ApprovalLineItem } from '../../src/lib/types/approval';

const emptySchema: FormSchema = { version: 1, fields: [] };

function mkInput(overrides: Partial<Parameters<typeof computeDocumentHash>[0]> = {}) {
  return {
    formSchema: emptySchema,
    content: { title: 't', amount: 1000 },
    approvalLine: [
      { userId: 'u1', stepType: 'approval' as const, groupOrder: 0 }
    ] as ApprovalLineItem[],
    attachmentSha256s: [] as string[],
    ...overrides
  };
}

describe('computeDocumentHash', () => {
  it('produces 64-char lowercase hex', async () => {
    const h = await computeDocumentHash(mkInput());
    expect(h).toMatch(/^[0-9a-f]{64}$/);
  });

  it('deterministic — same input twice yields same hash', async () => {
    const a = await computeDocumentHash(mkInput());
    const b = await computeDocumentHash(mkInput());
    expect(a).toBe(b);
  });

  it('key order in content does not affect hash', async () => {
    const a = await computeDocumentHash(
      mkInput({ content: { a: 1, b: 2, c: 3 } })
    );
    const b = await computeDocumentHash(
      mkInput({ content: { c: 3, a: 1, b: 2 } })
    );
    expect(a).toBe(b);
  });

  it('content change yields different hash', async () => {
    const a = await computeDocumentHash(mkInput({ content: { amount: 1000 } }));
    const b = await computeDocumentHash(mkInput({ content: { amount: 1001 } }));
    expect(a).not.toBe(b);
  });

  it('approvalLine order matters (business requirement)', async () => {
    const a = await computeDocumentHash(
      mkInput({
        approvalLine: [
          { userId: 'u1', stepType: 'approval', groupOrder: 0 },
          { userId: 'u2', stepType: 'approval', groupOrder: 1 }
        ]
      })
    );
    const b = await computeDocumentHash(
      mkInput({
        approvalLine: [
          { userId: 'u2', stepType: 'approval', groupOrder: 0 },
          { userId: 'u1', stepType: 'approval', groupOrder: 1 }
        ]
      })
    );
    expect(a).not.toBe(b);
  });

  it('attachmentSha256s order does NOT matter (sorted internally)', async () => {
    const a = await computeDocumentHash(
      mkInput({
        attachmentSha256s: [
          'a'.repeat(64),
          'b'.repeat(64),
          'c'.repeat(64)
        ]
      })
    );
    const b = await computeDocumentHash(
      mkInput({
        attachmentSha256s: [
          'c'.repeat(64),
          'a'.repeat(64),
          'b'.repeat(64)
        ]
      })
    );
    expect(a).toBe(b);
  });

  it('undefined groupOrder normalized to null (matches explicit null)', async () => {
    const a = await computeDocumentHash(
      mkInput({
        approvalLine: [
          { userId: 'u1', stepType: 'approval' }
          // groupOrder undefined
        ]
      })
    );
    const b = await computeDocumentHash(
      mkInput({
        approvalLine: [
          { userId: 'u1', stepType: 'approval', groupOrder: undefined }
        ]
      })
    );
    expect(a).toBe(b);
  });

  it('different schema yields different hash', async () => {
    const schemaA: FormSchema = { version: 1, fields: [] };
    const schemaB: FormSchema = {
      version: 1,
      fields: [{ id: 'x', type: 'text', label: 'X' }]
    };
    const a = await computeDocumentHash(mkInput({ formSchema: schemaA }));
    const b = await computeDocumentHash(mkInput({ formSchema: schemaB }));
    expect(a).not.toBe(b);
  });
});
