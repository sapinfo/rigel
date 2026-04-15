import { z } from 'zod';

/**
 * Unified form error shape for server actions.
 * Always present shape avoids discriminated union access issues in Svelte templates.
 */
export type FormErrors = {
  fields: Record<string, string>;
  form: string | null;
};

/**
 * Convert a Zod SafeParseError to FormErrors.
 * Takes the first error per field.
 */
export function zodErrors<T>(parsed: z.SafeParseError<T>): FormErrors {
  const fieldErrors: Record<string, string> = {};
  const flat = parsed.error.flatten();
  for (const [key, messages] of Object.entries(flat.fieldErrors) as [
    string,
    string[] | undefined
  ][]) {
    if (Array.isArray(messages) && messages.length > 0) {
      fieldErrors[key] = messages[0];
    }
  }

  // Root-level refine / transform 에러는 flatten() 이 formErrors 에 넣는다.
  // zodErrors 이전 버전은 이걸 드롭해서 "상신 눌러도 조용히 실패" 하는 사일런트
  // 버그 원인이 됐다. form 슬롯에 합쳐서 UI 에 반드시 노출되도록 한다.
  // 동시에 deep-nested issue (ex. line[1].stepType) 도 path 로 복원해서 수집.
  const messages: string[] = [...(flat.formErrors ?? [])];
  for (const issue of parsed.error.issues) {
    if (issue.path.length === 0) continue; // 이미 formErrors 처리됨
    const pathKey = issue.path.map((p) => String(p)).join('.');
    // fieldErrors 에 top-level 키로 이미 들어간 것(path.length === 1) 은 제외
    if (issue.path.length === 1 && fieldErrors[pathKey]) continue;
    messages.push(`${pathKey}: ${issue.message}`);
  }

  const form = messages.length > 0 ? messages.join(' / ') : null;
  return { fields: fieldErrors, form };
}

/**
 * Create a form-level error (no field-specific errors).
 */
export function formError(message: string): FormErrors {
  return { fields: {}, form: message };
}

/**
 * Empty errors object (for initial state helpers).
 */
export const NO_ERRORS: FormErrors = { fields: {}, form: null };
