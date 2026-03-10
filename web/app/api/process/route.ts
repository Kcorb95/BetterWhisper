import { NextRequest, NextResponse } from "next/server";
import { generateText } from "ai";
import { validateAuth } from "@/lib/auth";
import { getProcessingModel, getProcessingModelName } from "@/lib/providers";

type ProcessMode = "clean" | "format" | "custom";

interface ProcessRequest {
  text: string;
  mode: ProcessMode;
  customPrompt?: string;
}

const MAX_TEXT_LENGTH = 50_000;
const MAX_PROMPT_LENGTH = 5_000;

const SYSTEM_PROMPTS: Record<Exclude<ProcessMode, "custom">, string> = {
  clean: `You are a text cleanup assistant. Your job is to clean up speech-to-text transcriptions.

Rules:
- Fix punctuation and capitalization
- Remove filler words (um, uh, like, you know, I mean, sort of, kind of, basically, actually, right, so)
- Remove false starts and repeated words
- Preserve the original meaning and tone exactly
- Do NOT rephrase, rewrite, or add any content
- Output ONLY the cleaned text with no preamble or explanation`,

  format: `You are a text formatting assistant. Your job is to rewrite speech-to-text transcriptions as well-structured prose.

Rules:
- Rewrite the text as clear, well-structured prose
- Use proper paragraphs, punctuation, and formatting
- Remove all filler words and verbal tics
- Improve clarity and readability while preserving the original meaning
- Use markdown formatting where appropriate (headers, lists, etc.)
- Output ONLY the formatted text with no preamble or explanation`,
};

export async function POST(request: NextRequest) {
  // Auth check
  const authError = validateAuth(request);
  if (authError) return authError;

  try {
    const body = (await request.json()) as ProcessRequest;

    // Validate input
    if (!body.text || typeof body.text !== "string") {
      return NextResponse.json(
        { error: "Missing or invalid 'text' field" },
        { status: 400 }
      );
    }

    if (body.text.length > MAX_TEXT_LENGTH) {
      return NextResponse.json(
        { error: `Text exceeds maximum length of ${MAX_TEXT_LENGTH} characters` },
        { status: 400 }
      );
    }

    const validModes: ProcessMode[] = ["clean", "format", "custom"];
    if (!body.mode || !validModes.includes(body.mode)) {
      return NextResponse.json(
        { error: `Invalid 'mode'. Must be one of: ${validModes.join(", ")}` },
        { status: 400 }
      );
    }

    if (body.mode === "custom" && !body.customPrompt) {
      return NextResponse.json(
        { error: "Missing 'customPrompt' for custom mode" },
        { status: 400 }
      );
    }

    if (body.customPrompt && body.customPrompt.length > MAX_PROMPT_LENGTH) {
      return NextResponse.json(
        { error: `Custom prompt exceeds maximum length of ${MAX_PROMPT_LENGTH} characters` },
        { status: 400 }
      );
    }

    // Build system prompt
    const systemPrompt =
      body.mode === "custom"
        ? body.customPrompt!
        : SYSTEM_PROMPTS[body.mode];

    const model = getProcessingModel();
    const modelName = getProcessingModelName();

    const result = await generateText({
      model,
      system: systemPrompt,
      prompt: body.text,
    });

    return NextResponse.json({
      text: result.text,
      model: modelName,
    });
  } catch (error) {
    console.error(
      "Processing error:",
      error instanceof Error ? error.message : error
    );
    return NextResponse.json(
      { error: "Processing failed. Please try again." },
      { status: 500 }
    );
  }
}
