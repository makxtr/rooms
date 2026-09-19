import createClient from "openapi-fetch";
import type { components, paths } from "./schema";

export const api = createClient<paths>({
  // Absolute, because Request() in non-browser runtimes (tests) rejects relative URLs.
  baseUrl: `${window.location.origin}/api/v1`,
  // Looked up per call rather than captured at import time, so tests can stub it.
  fetch: (request) => globalThis.fetch(request),
});

export type Problem = components["schemas"]["Problem"];

/** A non-successful API response. `problem` is set when the body was a problem document. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly problem?: Problem,
  ) {
    super(problem?.title ?? `HTTP ${status}`);
    this.name = "ApiError";
  }
}

function isProblem(value: unknown): value is Problem {
  if (typeof value !== "object" || value === null || !("code" in value) || !("title" in value)) {
    return false;
  }
  const candidate = value as Record<string, unknown>;
  return typeof candidate.code === "string" && typeof candidate.title === "string";
}

/** Builds the ApiError for a non-successful (or, for unwrap, body-less) response. */
function toApiError(result: { error?: unknown; response: Response }): ApiError {
  return new ApiError(result.response.status, isProblem(result.error) ? result.error : undefined);
}

/**
 * Turns an openapi-fetch result into data or a thrown ApiError. Use this for operations
 * whose successful response has a body: an OK response without data is a contract
 * violation and throws, same as an error response. Checking `error` alone is not enough,
 * because an error response with an empty or non-JSON body has no usable `error` value.
 */
export function unwrap<T>(result: { data?: T; error?: unknown; response: Response }): T {
  if (result.response.ok && result.data !== undefined) return result.data;
  throw toApiError(result);
}

/**
 * Turns an openapi-fetch result into void or a thrown ApiError. Use this for operations
 * whose successful response has no body (a 204, for instance) — unlike `unwrap`, a
 * body-less success is not an error here.
 */
export function unwrapEmpty(result: { error?: unknown; response: Response }): void {
  if (result.response.ok) return;
  throw toApiError(result);
}
