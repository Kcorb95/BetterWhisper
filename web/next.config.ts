import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Allow larger request bodies for audio file uploads (25MB)
  experimental: {
    serverActions: {
      bodySizeLimit: "25mb",
    },
  },
};

export default nextConfig;
