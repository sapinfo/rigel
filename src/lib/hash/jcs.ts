// src/lib/hash/jcs.ts
// RFC 8785 JSON Canonicalization Scheme — Rigel 제한 사양.
//
// 지원: null / boolean / number (ECMA-262 Number.toString, -0 → 0) / string
//       (RFC 8259 minimal escape) / array (순서 유지) / object (UTF-16 code unit 정렬)
//
// 미지원 (Rigel content 상 발생 불가 — 발견 시 프로그래밍 오류로 간주):
//   - BigInt
//   - Infinity / NaN
//   - undefined (object 필드 값)
//   - 함수, Symbol, Date 객체 (상위 계층에서 string 변환해야 함)
//
// Reference: https://tools.ietf.org/html/rfc8785

export function canonicalize(value: unknown): string {
  return serialize(value);
}

function serialize(v: unknown): string {
  if (v === null) return 'null';
  if (v === undefined) {
    throw new Error('JCS: undefined values not allowed');
  }
  const t = typeof v;
  if (t === 'boolean') return v ? 'true' : 'false';
  if (t === 'number') return serializeNumber(v as number);
  if (t === 'string') return serializeString(v as string);
  if (t === 'bigint') {
    throw new Error('JCS: BigInt not supported');
  }
  if (Array.isArray(v)) {
    return '[' + v.map((item) => serialize(item)).join(',') + ']';
  }
  if (t === 'object') {
    const obj = v as Record<string, unknown>;
    // UTF-16 code unit 기준 정렬 — JS String compare 가 이미 code unit 순서.
    const keys = Object.keys(obj).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
    const parts: string[] = [];
    for (const k of keys) {
      parts.push(serializeString(k) + ':' + serialize(obj[k]));
    }
    return '{' + parts.join(',') + '}';
  }
  throw new Error(`JCS: unsupported type ${t}`);
}

function serializeNumber(n: number): string {
  if (!Number.isFinite(n)) {
    throw new Error(`JCS: non-finite number ${n}`);
  }
  // -0 은 0 으로 정규화 (RFC 8785 §3.2.2.3)
  if (Object.is(n, -0)) return '0';
  // ECMA-262 Number.prototype.toString 이 이미 RFC 7493/8785 호환 출력을 냄
  // (15자리 dtoa, 필요 시 지수 표기 e+/e- 대신 JS 기본).
  return n.toString();
}

// RFC 8259 §7 (JCS §3.2.2.2 동일) — 최소 escape set
function serializeString(s: string): string {
  let out = '"';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c === 0x22) out += '\\"';          // "
    else if (c === 0x5c) out += '\\\\';    // \
    else if (c === 0x08) out += '\\b';     // backspace
    else if (c === 0x09) out += '\\t';     // tab
    else if (c === 0x0a) out += '\\n';     // newline
    else if (c === 0x0c) out += '\\f';     // form feed
    else if (c === 0x0d) out += '\\r';     // carriage return
    else if (c < 0x20) {
      out += '\\u' + c.toString(16).padStart(4, '0');
    } else {
      out += s[i];
    }
  }
  return out + '"';
}
