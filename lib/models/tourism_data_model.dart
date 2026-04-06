class TourismData {
  final String category;
  final String name;
  final String description;
  final List<String> keywords;

  TourismData({
    required this.category,
    required this.name,
    required this.description,
    required this.keywords,
  });

  factory TourismData.fromJson(Map<String, dynamic> json) {
    return TourismData(
      category: json['category'],
      name: json['name'],
      description: json['description'],
      keywords: List<String>.from(json['keywords']),
    );
  }
}
