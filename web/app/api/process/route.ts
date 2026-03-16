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
  clean: `Clean up the following speech transcription. Remove filler words (um, uh, like, you know, etc.), false starts, and repetitions. Fix punctuation and capitalization. Preserve every piece of actual content exactly — do not rephrase, summarize, or omit anything the speaker said. Output only the cleaned transcription.`,

  format: `Reformat the following speech transcription as well-structured prose. Remove filler words and verbal tics. Use proper paragraphs, punctuation, and markdown formatting. Preserve the full meaning and all content — do not summarize or omit anything the speaker said. Output only the formatted transcription.`,
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
      temperature: 0,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: body.text },
        { role: "assistant", content: "<transcription>" },
      ],
    });

    // Strip closing tag from assistant prefill
    const text = result.text.replace(/<\/transcription>\s*$/, "").trim();

    return NextResponse.json({
      text,
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
