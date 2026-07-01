class AiModel {
  final String id;
  final String name;
  final String? description;

  const AiModel({required this.id, required this.name, this.description});

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? json['id'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is AiModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
