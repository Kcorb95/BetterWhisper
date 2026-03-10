import { NextRequest, NextResponse } from "next/server";
import { validateAuth } from "@/lib/auth";
import { getTranscriptionClient, getTranscriptionModel } from "@/lib/providers";

const MAX_FILE_SIZE = 25 * 1024 * 1024; // 25 MB

export async function POST(request: NextRequest) {
  // Auth check
  const authError = validateAuth(request);
  if (authError) return authError;

  try {
    const formData = await request.formData();
    const audioFile = formData.get("file");

    if (!audioFile || !(audioFile instanceof File)) {
      return NextResponse.json(
        { error: "Missing or invalid 'file' field. Must be an audio file." },
        { status: 400 }
      );
    }

    if (audioFile.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: "File too large. Maximum size is 25MB." },
        { status: 413 }
      );
    }

    const client = getTranscriptionClient();
    const model = getTranscriptionModel();

    const start = performance.now();

    const transcription = await client.audio.transcriptions.create({
      file: audioFile,
      model,
      response_format: "verbose_json",
    });

    const duration = Math.round(performance.now() - start);

    return NextResponse.json({
      text: transcription.text,
      duration,
    });
  } catch (error) {
    console.error(
      "Transcription error:",
      error instanceof Error ? error.message : error
    );
    return NextResponse.json(
      { error: "Transcription failed. Please try again." },
      { status: 500 }
    );
  }
}
