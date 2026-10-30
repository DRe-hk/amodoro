export const dynamic = "force-dynamic";

export async function GET() {
  const packageName = process.env.ANDROID_PACKAGE_NAME ?? "com.amodoro.app";
  const rawFingerprint = process.env.ANDROID_SHA256_FINGERPRINT;

  const fingerprints: string[] = rawFingerprint
    ? rawFingerprint
        .split(",")
        .map((f) => f.trim())
        .filter(Boolean)
    : [];

  const assetLinks = [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: packageName,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ];

  return Response.json(assetLinks, {
    headers: {
      "content-type": "application/json",
      "cache-control": "public, max-age=3600, s-maxage=3600",
    },
  });
}
