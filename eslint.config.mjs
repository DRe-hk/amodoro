import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Every image Nido serves is behind the session check on
    // /api/media/[id], and video needs byte ranges. next/image would fetch
    // through its optimizer without the cookie, and would break seeking, so
    // these surfaces use <img>/<video> on purpose.
    files: ["src/app/lienzo/**", "src/app/api/media/**"],
    rules: { "@next/next/no-img-element": "off" },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
