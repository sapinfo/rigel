import { describe, it, expect } from 'vitest';
import { canonicalize } from '../../src/lib/hash/jcs';

describe('JCS RFC 8785 — Rigel 제한 사양', () => {
  describe('primitives', () => {
    it('null', () => expect(canonicalize(null)).toBe('null'));
    it('true / false', () => {
      expect(canonicalize(true)).toBe('true');
      expect(canonicalize(false)).toBe('false');
    });
    it('positive integer', () => expect(canonicalize(42)).toBe('42'));
    it('negative integer', () => expect(canonicalize(-7)).toBe('-7'));
    it('float', () => expect(canonicalize(1.5)).toBe('1.5'));
    it('-0 → 0', () => expect(canonicalize(-0)).toBe('0'));
    it('empty string', () => expect(canonicalize('')).toBe('""'));
    it('ascii string', () => expect(canonicalize('hello')).toBe('"hello"'));
    it('string with escape', () => {
      expect(canonicalize('a"b')).toBe('"a\\"b"');
      expect(canonicalize('a\\b')).toBe('"a\\\\b"');
    });
    it('control chars', () => {
      expect(canonicalize('\n')).toBe('"\\n"');
      expect(canonicalize('\t')).toBe('"\\t"');
      expect(canonicalize('\r')).toBe('"\\r"');
      expect(canonicalize('\u0001')).toBe('"\\u0001"');
    });
    it('hangul passes through (non-control > 0x20)', () => {
      expect(canonicalize('안녕')).toBe('"안녕"');
    });
  });

  describe('arrays', () => {
    it('empty', () => expect(canonicalize([])).toBe('[]'));
    it('preserves order', () => expect(canonicalize([3, 1, 2])).toBe('[3,1,2]'));
    it('nested', () =>
      expect(canonicalize([[1, 2], [3]])).toBe('[[1,2],[3]]'));
    it('mixed types', () =>
      expect(canonicalize([1, 'a', null, true])).toBe('[1,"a",null,true]'));
  });

  describe('objects', () => {
    it('empty', () => expect(canonicalize({})).toBe('{}'));

    it('sorts keys (UTF-16 code unit)', () => {
      expect(canonicalize({ b: 1, a: 2 })).toBe('{"a":2,"b":1}');
    });

    it('sorts keys including numeric-like', () => {
      // "10" < "2" in lexicographic code-unit order
      expect(canonicalize({ '2': 'two', '10': 'ten' })).toBe(
        '{"10":"ten","2":"two"}'
      );
    });

    it('nested objects recursively sorted', () => {
      expect(canonicalize({ a: { c: 1, b: 2 } })).toBe('{"a":{"b":2,"c":1}}');
    });

    it('key order independence', () => {
      const a = canonicalize({ x: 1, y: 2, z: 3 });
      const b = canonicalize({ z: 3, x: 1, y: 2 });
      const c = canonicalize({ y: 2, z: 3, x: 1 });
      expect(a).toBe(b);
      expect(b).toBe(c);
    });
  });

  describe('real-world Rigel content', () => {
    it('form content with hangul', () => {
      const content = {
        title: '출장비 신청',
        amount: 50000,
        purpose: '고객사 방문'
      };
      const out = canonicalize(content);
      expect(out).toBe(
        '{"amount":50000,"purpose":"고객사 방문","title":"출장비 신청"}'
      );
    });

    it('approval line normalized', () => {
      const line = [
        { userId: 'u1', stepType: 'approval', groupOrder: 0 },
        { userId: 'u2', stepType: 'approval', groupOrder: 0 },
        { userId: 'u3', stepType: 'reference', groupOrder: 1 }
      ];
      const out = canonicalize(line);
      // array 순서 유지, object 내부 키 정렬
      expect(out).toBe(
        '[' +
          '{"groupOrder":0,"stepType":"approval","userId":"u1"},' +
          '{"groupOrder":0,"stepType":"approval","userId":"u2"},' +
          '{"groupOrder":1,"stepType":"reference","userId":"u3"}' +
          ']'
      );
    });
  });

  describe('unsupported types', () => {
    it('undefined throws', () => {
      expect(() => canonicalize(undefined)).toThrow('JCS: undefined');
    });
    it('undefined inside object throws', () => {
      expect(() => canonicalize({ a: undefined })).toThrow('JCS: undefined');
    });
    it('BigInt throws', () => {
      expect(() => canonicalize(1n)).toThrow('JCS: BigInt');
    });
    it('Infinity throws', () => {
      expect(() => canonicalize(Infinity)).toThrow('JCS: non-finite');
    });
    it('NaN throws', () => {
      expect(() => canonicalize(NaN)).toThrow('JCS: non-finite');
    });
  });
});
