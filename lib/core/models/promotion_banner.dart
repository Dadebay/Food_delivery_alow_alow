class PromotionBanner {
  const PromotionBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.link,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? link;

  factory PromotionBanner.fromJson(Map<String, dynamic> json) =>
      PromotionBanner(
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        link: json['link'] as String?,
      );
}
