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
  return { fields: fieldErrors, form: null };
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
