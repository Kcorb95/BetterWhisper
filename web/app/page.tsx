export default function Home() {
  return (
    <div className="min-h-screen bg-neutral-950 text-neutral-100 flex items-center justify-center p-8">
      <main className="max-w-2xl w-full space-y-12">
        <div className="space-y-4">
          <h1 className="text-4xl font-bold tracking-tight">BetterWhisper</h1>
          <p className="text-lg text-neutral-400">
            AI-powered speech-to-text gateway for macOS. Transcribe audio with
            Whisper and optionally polish the output with an LLM.
          </p>
        </div>

        <div className="space-y-6">
          <h2 className="text-xl font-semibold text-neutral-200">
            API Endpoints
          </h2>

          <div className="space-y-4 font-mono text-sm">
            <div className="rounded-lg border border-neutral-800 bg-neutral-900 p-4 space-y-2">
              <div className="flex items-center gap-2">
                <span className="rounded bg-green-900/50 px-2 py-0.5 text-xs text-green-400 font-semibold">
                  POST
                </span>
                <span className="text-neutral-200">/api/transcribe</span>
              </div>
              <p className="text-neutral-500 font-sans text-sm">
                Upload an audio file for transcription. Returns raw transcript
                text.
              </p>
            </div>

            <div className="rounded-lg border border-neutral-800 bg-neutral-900 p-4 space-y-2">
              <div className="flex items-center gap-2">
                <span className="rounded bg-green-900/50 px-2 py-0.5 text-xs text-green-400 font-semibold">
                  POST
                </span>
                <span className="text-neutral-200">/api/process</span>
              </div>
              <p className="text-neutral-500 font-sans text-sm">
                Post-process transcribed text. Modes: clean, format, or custom
                prompt.
              </p>
            </div>

            <div className="rounded-lg border border-neutral-800 bg-neutral-900 p-4 space-y-2">
              <div className="flex items-center gap-2">
                <span className="rounded bg-blue-900/50 px-2 py-0.5 text-xs text-blue-400 font-semibold">
                  GET
                </span>
                <span className="text-neutral-200">/api/health</span>
              </div>
              <p className="text-neutral-500 font-sans text-sm">
                Health check. Returns configured provider information.
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-semibold text-neutral-200">Get Started</h2>
          <p className="text-neutral-400 text-sm">
            Download the macOS app and follow the setup guide on GitHub.
          </p>
          <a
            href="https://github.com/Kcorb95/BetterWhisper"
            className="inline-flex items-center gap-2 rounded-lg bg-neutral-800 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-700 transition-colors"
          >
            View on GitHub &rarr;
          </a>
        </div>

        <footer className="text-xs text-neutral-600 pt-8 border-t border-neutral-800">
          BetterWhisper &mdash; Runs on Vercel. Powered by Groq Whisper &amp;
          Claude.
        </footer>
      </main>
    </div>
  );
}
