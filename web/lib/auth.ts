import { createHash, timingSafeEqual } from "crypto";
import { NextRequest, NextResponse } from "next/server";

// Cache the expected hash since AUTH_TOKEN doesn't change at runtime
let expectedHashCache: Buffer | null = null;

function getExpectedHash(authToken: string): Buffer {
  if (!expectedHashCache) {
    expectedHashCache = createHash("sha256").update(authToken).digest();
  }
  return expectedHashCache;
}

/**
 * Validates the Authorization header against the AUTH_TOKEN env var.
 * AUTH_TOKEN is required — the server refuses all requests without it.
 * Returns null if auth passes, or a 401/500 NextResponse if it fails.
 */
export function validateAuth(request: NextRequest): NextResponse | null {
  const authToken = process.env.AUTH_TOKEN;

  if (!authToken) {
    return NextResponse.json(
      { error: "Server configuration error" },
      { status: 500 }
    );
  }

  const authorization = request.headers.get("authorization");
  if (!authorization) {
    return NextResponse.json(
      { error: "Missing Authorization header" },
      { status: 401 }
    );
  }

  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    return NextResponse.json(
      { error: "Missing token in Authorization header" },
      { status: 401 }
    );
  }

  // Constant-time comparison to prevent timing attacks
  const tokenHash = createHash("sha256").update(token).digest();
  const expectedHash = getExpectedHash(authToken);
  if (!timingSafeEqual(tokenHash, expectedHash)) {
    return NextResponse.json(
      { error: "Invalid authorization token" },
      { status: 401 }
    );
  }

  return null;
}
