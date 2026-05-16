class PublishResult {
  const PublishResult({
    required this.publicSlug,
    this.propertyUrl,
    this.tourUrl,
  });

  final String publicSlug;
  final String? propertyUrl;
  final String? tourUrl;

  factory PublishResult.fromJson(Map<String, dynamic> json) {
    final share = json['shareUrls'] as Map<String, dynamic>?;
    return PublishResult(
      publicSlug: json['publicSlug'] as String? ?? '',
      propertyUrl: share?['property'] as String?,
      tourUrl: share?['tour'] as String?,
    );
  }

  String get primaryShareUrl => tourUrl ?? propertyUrl ?? '';
}
