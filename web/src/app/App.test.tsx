import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { App } from "./App";

function renderApp() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <App />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("App", () => {
  it("shows the backend status reported by /health", async () => {
    const fetchMock = vi.fn(
      async (_request: Request) =>
        new Response(JSON.stringify({ status: "ok" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
    );
    vi.stubGlobal("fetch", fetchMock);

    renderApp();

    expect(await screen.findByText("backend: ok")).toBeInTheDocument();
    const request = fetchMock.mock.calls[0]?.[0];
    expect(request).toBeDefined();
    expect(new URL(request!.url).pathname).toBe("/api/v1/health");
  });

  it("reports an unavailable backend", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new TypeError("network down");
      }),
    );

    renderApp();

    expect(await screen.findByText("backend: unavailable")).toBeInTheDocument();
  });

  it("reports an unavailable backend for an empty 502 from the proxy", async () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_request: Request) => new Response(null, { status: 502 })),
    );

    renderApp();

    expect(await screen.findByText("backend: unavailable")).toBeInTheDocument();
    // Reaching "unavailable" through TanStack Query's "data cannot be undefined"
    // complaint would be an accident, not error handling.
    expect(consoleError).not.toHaveBeenCalled();
  });
});
