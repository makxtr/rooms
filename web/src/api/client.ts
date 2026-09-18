import createClient from "openapi-fetch";
import type { paths } from "./schema";

export const api = createClient<paths>({
  // Absolute, because Request() in non-browser runtimes (tests) rejects relative URLs.
  baseUrl: `${window.location.origin}/api/v1`,
  // Looked up per call rather than captured at import time, so tests can stub it.
  fetch: (request) => globalThis.fetch(request),
});
