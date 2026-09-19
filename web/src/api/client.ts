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
  return typeof value === "object" && value !== null && "code" in value && "title" in value;
}

/**
 * Turns an openapi-fetch result into data or a thrown ApiError. Every query and
 * mutation goes through this: checking `error` alone is not enough, because an
 * error response with an empty or non-JSON body has no usable `error` value.
 */
export function unwrap<T>(result: { data?: T; error?: unknown; response: Response }): T {
  if (result.response.ok && result.data !== undefined) return result.data;
  throw new ApiError(result.response.status, isProblem(result.error) ? result.error : undefined);
}
