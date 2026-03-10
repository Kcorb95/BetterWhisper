import { gateway } from "@ai-sdk/gateway";
import OpenAI from "openai";

// ── Transcription (Groq Whisper) ────────────────────────────────
// Groq handles audio transcription via their OpenAI-compatible API.
// API key is auto-added by the Groq Vercel integration.

let cachedClient: OpenAI | null = null;

export function getTranscriptionClient(): OpenAI {
  if (cachedClient) return cachedClient;

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey)
    throw new Error(
      "GROQ_API_KEY is required. Add the Groq integration in your Vercel project, or set it manually for local dev."
    );

  cachedClient = new OpenAI({
    apiKey,
    baseURL: "https://api.groq.com/openai/v1",
  });
  return cachedClient;
}

export function getTranscriptionModel(): string {
  return "whisper-large-v3-turbo";
}

// ── Post-processing (LLM via AI Gateway) ─────────────────────────
// Uses Vercel AI Gateway — one API key, any provider/model.
// On Vercel deployments, auth is automatic via OIDC (no key needed).
// Model format: "provider/model-name" e.g. "anthropic/claude-haiku-4.5"

const DEFAULT_PROCESSING_MODEL = "anthropic/claude-haiku-4.5";

export function getProcessingModel() {
  const model = process.env.PROCESSING_MODEL ?? DEFAULT_PROCESSING_MODEL;
  return gateway(model);
}

export function getProcessingModelName(): string {
  return process.env.PROCESSING_MODEL ?? DEFAULT_PROCESSING_MODEL;
}
