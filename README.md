# BetterWhisper

Hold a hotkey, speak, release. Your speech is transcribed and pasted into the active app. Open-source and self-hosted.

**macOS native app** + **Vercel backend** you deploy yourself.

---

## Install

### 1. Download the app

Grab the latest `.dmg` from [**Releases**](../../releases), open it, and drag BetterWhisper to your Applications folder.

### 2. Deploy the backend

Click the button below to deploy your own backend to Vercel:

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2FKcorb95%2FBetterWhisper%2Ftree%2Fmain%2Fweb&env=AUTH_TOKEN,GROQ_API_KEY&envDescription=API%20keys%20for%20BetterWhisper&project-name=betterwhisper)

During setup, you'll be prompted for two environment variables:

- **`AUTH_TOKEN`**, a shared secret between your app and backend (see [Generating a secure token](#4-generating-a-secure-token))
- **`GROQ_API_KEY`**, which gets added automatically when you set up the Groq integration (next step)

### 3. Add Vercel integrations

After deploying, add two integrations to your Vercel project.

#### Groq (for speech-to-text)

1. Go to [vercel.com/integrations/groq](https://vercel.com/integrations/groq) and click **Add Integration**
2. Select the project you just deployed
3. `GROQ_API_KEY` gets added to your project automatically

#### AI Gateway (for LLM processing)

AI Gateway lets BetterWhisper use any LLM (Claude, GPT, Gemini, and others) for cleaning up transcriptions.

1. Go to [vercel.com/integrations/ai-gateway](https://vercel.com/integrations/ai-gateway) and click **Add Integration**
2. Select your project
3. In your Vercel Dashboard, go to **AI Gateway** in the left sidebar
4. **Top up your balance** so the gateway can make API calls on your behalf
5. Go to **API Keys** and create a new key
6. Add the key as `AI_GATEWAY_API_KEY` in your project's **Settings > Environment Variables**
7. **Redeploy** your project for the new variable to take effect

> On Vercel, AI Gateway auth works automatically via OIDC for most cases. `AI_GATEWAY_API_KEY` is a fallback. If things work without it, you can skip steps 5 through 7.

### 4. Generating a secure token

Your auth token is a shared secret between the macOS app and your backend. Anyone with this token can use your backend and spend your API credits, so keep it private.

Generate one in your terminal:

```bash
openssl rand -base64 32
```

Use this value as `AUTH_TOKEN` in both Vercel (environment variable) and the BetterWhisper app (Settings).

### 5. Configure the app

1. Click the BetterWhisper icon in your menu bar
2. Open **Settings**
3. Enter your Vercel deployment URL (e.g., `https://your-app.vercel.app`)
4. Enter the same `AUTH_TOKEN` you set on the server
5. Grant **Microphone** and **Accessibility** permissions when prompted
6. Hold your hotkey (default: Right Option) and start talking

## How it works

```
Hold hotkey > Record > Release > Transcribe (Whisper) > Process (LLM) > Paste
```

Audio is recorded locally, compressed, and sent to your Vercel backend. Whisper transcribes it, then an LLM optionally cleans or formats the text. The result is pasted into whatever app is focused.

## Features

- **Hold-to-talk or toggle** recording modes
- **Processing modes** including raw transcript, clean (grammar and filler removal), format (structured prose), or custom (your own AI prompt)
- **Any LLM** via AI Gateway, including Claude, GPT, Gemini, and 100+ models
- **Fast transcription** with Groq Whisper
- **Auto-paste** into your active app via simulated Cmd+V
- **History** with searchable archive of all transcriptions
- **Update notifications** that check GitHub for new versions on launch
- **Self-hosted** on your own server with your own API keys

## Processing modes

| Mode | What it does |
|------|-------------|
| **Raw** | No processing, verbatim Whisper output |
| **Clean** | Fixes punctuation, removes filler words (um, uh, like, you know) |
| **Format** | Rewrites as structured prose with markdown |
| **Custom** | Your own system prompt for translation, summarization, or anything else |

## Switching models

Change `PROCESSING_MODEL` to any [AI Gateway](https://vercel.com/docs/ai-gateway) model:

```bash
PROCESSING_MODEL=anthropic/claude-sonnet-4.6
PROCESSING_MODEL=openai/gpt-5-mini
PROCESSING_MODEL=google/gemini-3-flash
```

AI Gateway handles provider auth, so no additional API keys are needed.

## Architecture

```
macOS App (Swift/AppKit)           Vercel Backend (Next.js)
┌─────────────────────┐           ┌──────────────────────────────┐
│                     │   HTTPS   │                              │
│  Menu bar UI        │ ────────> │  POST /api/transcribe        │
│  Audio recording    │           │  > Groq Whisper              │
│  Global hotkey      │           │                              │
│  Clipboard + paste  │           │  POST /api/process           │
│  Local history      │           │  > AI Gateway > any LLM      │
│                     │           │                              │
│                     │           │  GET  /api/health            │
└─────────────────────┘           └──────────────────────────────┘
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AUTH_TOKEN` | **Yes** | | Shared secret between app and server |
| `GROQ_API_KEY` | **Yes** | | Auto-added by Groq integration |
| `AI_GATEWAY_API_KEY` | Local dev only | | Auto via OIDC on Vercel |
| `PROCESSING_MODEL` | No | `anthropic/claude-haiku-4.5` | Format: `provider/model` |

## Permissions

| Permission | Why | How to grant |
|------------|-----|--------------|
| **Microphone** | Record audio for transcription | Prompted on first use, or System Settings > Privacy & Security > Microphone |
| **Accessibility** | Global hotkey detection and paste simulation | System Settings > Privacy & Security > Accessibility |

## Troubleshooting

**"Not configured" in menu bar**
Open Settings and enter your server URL and auth token.

**Hotkey not working**
Grant Accessibility in System Settings > Privacy & Security > Accessibility. You may need to remove and re-add the app.

**No audio or "Microphone access required"**
Grant Microphone in System Settings > Privacy & Security > Microphone.

**"Authentication failed"**
Make sure the auth token in the app matches the `AUTH_TOKEN` env var on your server.

**Paste not working**
Auto-paste requires Accessibility permission. Text is always copied to your clipboard as a fallback, so you can Cmd+V manually.

## Building from source

### macOS app

Requires Xcode command-line tools and macOS 14+.

```bash
cd macos/BetterWhisper
swift build -c release
```

### Backend (local development)

To run the backend locally instead of on Vercel:

```bash
cd web
npm install
cp .env.example .env.local
```

Fill in your `.env.local`:

- `GROQ_API_KEY` from [console.groq.com](https://console.groq.com)
- `AI_GATEWAY_API_KEY` from Vercel Dashboard > AI Gateway > API Keys
- `AUTH_TOKEN`, same token you use in the app

```bash
npm run dev   # http://localhost:3000
```

Then point the BetterWhisper app at `http://localhost:3000` in Settings.

### Publishing a release

```bash
./scripts/bundle.sh          # dist/BetterWhisper.app
./scripts/create-dmg.sh      # dist/BetterWhisper.dmg
```

Upload `dist/BetterWhisper.dmg` to a new [GitHub Release](../../releases/new) with a version tag (e.g., `v1.0.1`).

## License

[BSL 1.1](LICENSE). Free to use, modify, and self-host. Commercial use (selling, reselling, or offering as a paid service) requires a license from the author.
