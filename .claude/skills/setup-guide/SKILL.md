---
name: setup-guide
description: Walk a user through setting up BetterWhisper on their Mac — downloading, deploying the backend, configuring integrations, and testing.
allowed-tools: Bash, Read, WebFetch
---

# BetterWhisper Setup Guide

Walk the user through setting up BetterWhisper step by step. Be conversational and helpful — assume they are non-technical. Wait for confirmation after each major step before moving on.

## Step 1: Download and install the app

- Direct them to download BetterWhisper.dmg from https://github.com/Kcorb95/BetterWhisper/releases/latest
- Tell them to open the DMG and drag BetterWhisper to Applications
- If the app is not notarized: tell them to right-click → Open on first launch to bypass Gatekeeper
- Confirm they see the BetterWhisper icon in their menu bar

## Step 2: Generate a secure auth token

- Have them run `openssl rand -base64 32` in their terminal (you can run this for them)
- Explain this is a shared secret between their app and their server — keep it private
- Tell them to copy and save it somewhere temporarily — they'll need it in two places

## Step 3: Deploy the backend to Vercel

- Direct them to click the Deploy button on the GitHub README, or give them this URL:
  https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2FKcorb95%2FBetterWhisper%2Ftree%2Fmain%2Fweb&env=AUTH_TOKEN,GROQ_API_KEY&envDescription=API%20keys%20for%20BetterWhisper&project-name=betterwhisper
- When prompted for AUTH_TOKEN, paste the token they generated in Step 2
- For GROQ_API_KEY, they can enter a placeholder for now — the Groq integration will replace it
- Wait for deploy to complete and confirm they have a URL like `https://betterwhisper-xxx.vercel.app`

## Step 4: Add the Groq integration

- Go to https://vercel.com/integrations/groq → Add Integration
- Select the BetterWhisper project they just deployed
- This automatically adds the GROQ_API_KEY environment variable
- They may need to redeploy for it to take effect

## Step 5: Add AI Gateway integration

- Go to https://vercel.com/integrations/ai-gateway → Add Integration
- Select their project
- In Vercel Dashboard → AI Gateway (left sidebar):
  1. Top up their balance (add credits)
  2. Go to API Keys → create a new key
  3. Copy the key
- Go to project Settings → Environment Variables → add `AI_GATEWAY_API_KEY` with the key
- Redeploy the project

Note: On Vercel, AI Gateway often works automatically via OIDC without a manual key. If things work without it, they can skip the API key step.

## Step 6: Configure the app

- Click the BetterWhisper icon in the menu bar → Settings
- Enter their Vercel deployment URL (e.g., `https://betterwhisper-xxx.vercel.app`)
- Enter the same AUTH_TOKEN from Step 2
- Grant Microphone and Accessibility permissions when prompted

## Step 7: Test it

- Hold the hotkey (default: Right Option key) and say something
- Release the key
- They should see their speech transcribed and pasted into whatever app is focused
- If it doesn't work, walk through the Troubleshooting section of the README

## Troubleshooting tips

- "Not configured" → Settings not filled in
- Hotkey not working → Accessibility permission not granted (System Settings → Privacy & Security → Accessibility). May need to remove and re-add
- No audio → Microphone permission not granted
- "Authentication failed" → AUTH_TOKEN mismatch between app and server
- Paste not working → Accessibility permission needed. Text is still on clipboard — Cmd+V manually
