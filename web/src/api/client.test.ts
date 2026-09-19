import { describe, expect, it } from "vitest";
import { ApiError, unwrap, unwrapEmpty } from "./client";

const response = (status: number) => new Response(null, { status });
const problem = { type: "about:blank", title: "Forbidden", status: 403, code: "room.banned" };

describe("unwrap", () => {
  it("returns data of a successful response", () => {
    expect(unwrap({ data: { status: "ok" }, response: response(200) })).toEqual({ status: "ok" });
  });

  it("throws ApiError carrying the problem document", () => {
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

  it("does not trust a problem-shaped body whose fields are not strings", () => {
    try {
      unwrap({ error: { title: 1, code: 2 }, response: response(400) });
      expect.unreachable("unwrap returned for an error response");
    } catch (e) {
      expect((e as ApiError).problem).toBeUndefined();
      expect((e as ApiError).message).toBe("HTTP 400");
    }
  });
});

describe("unwrapEmpty", () => {
  it("returns undefined for a body-less successful response", () => {
    expect(unwrapEmpty({ response: response(204) })).toBeUndefined();
  });

  it("throws ApiError carrying the problem document", () => {
    try {
      unwrapEmpty({ error: problem, response: response(403) });
      expect.unreachable("unwrapEmpty returned for an error response");
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      const err = e as ApiError;
      expect(err.status).toBe(403);
      expect(err.problem?.code).toBe("room.banned");
    }
  });

  it("throws for an error response with an empty body", () => {
    expect(() => unwrapEmpty({ response: response(502) })).toThrowError(new ApiError(502));
  });
});
