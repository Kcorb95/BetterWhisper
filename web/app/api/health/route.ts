import { NextRequest, NextResponse } from "next/server";
import { validateAuth } from "@/lib/auth";

export async function GET(request: NextRequest) {
  const authError = validateAuth(request);
  if (authError) return authError;

  return NextResponse.json({ status: "ok" });
}
