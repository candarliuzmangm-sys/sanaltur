/** Medya URL'lerini dış cihazların erişebileceği API_PUBLIC_URL host'una çevirir. */
export function resolvePublicMediaUrl(
  url: string | null | undefined,
  apiPublicUrl: string,
): string | undefined {
  if (!url) return undefined;
  try {
    const base = new URL(apiPublicUrl);
    const parsed = new URL(url);
    if (
      parsed.hostname === 'localhost' ||
      parsed.hostname === '127.0.0.1' ||
      parsed.hostname === '10.0.2.2'
    ) {
      parsed.protocol = base.protocol;
      parsed.hostname = base.hostname;
      parsed.port = base.port;
      return parsed.toString();
    }
  } catch {
    return url;
  }
  return url;
}

export function buildShareUrls(
  publicWebUrl: string,
  publicSlug: string,
  tourSlug?: string | null,
) {
  const base = publicWebUrl.replace(/\/$/, '');
  return {
    property: `${base}/p/${publicSlug}`,
    tour: tourSlug ? `${base}/tour/${tourSlug}` : null,
  };
}
