import { describe, expect, it } from "vitest";
import { ApiError, unwrap } from "./client";

const response = (status: number) => new Response(null, { status });

describe("unwrap", () => {
  it("returns data of a successful response", () => {
    expect(unwrap({ data: { status: "ok" }, response: response(200) })).toEqual({ status: "ok" });
  });

  it("throws ApiError carrying the problem document", () => {
    const problem = { type: "about:blank", title: "Forbidden", status: 403, code: "room.banned" };
    try {
      unwrap({ error: problem, response: response(403) });
      expect.unreachable("unwrap returned for an error response");
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      const err = e as ApiError;
      expect(err.status).toBe(403);
      expect(err.problem?.code).toBe("room.banned");
      expect(err.message).toBe("Forbidden");
    }
  });

  // openapi-fetch yields `error: undefined` for an error response with an empty
  // body (a proxy's 502, for instance). That must not read as success.
  it("throws for an error response with an empty body", () => {
    expect(() => unwrap({ response: response(502) })).toThrowError(new ApiError(502));
  });

  it("does not trust a non-problem error body", () => {
    try {
      unwrap({ error: "Bad Gateway", response: response(502) });
      expect.unreachable("unwrap returned for an error response");
    } catch (e) {
      expect((e as ApiError).problem).toBeUndefined();
      expect((e as ApiError).message).toBe("HTTP 502");
    }
  });
});
