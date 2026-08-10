class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  final String id;

  /// Display name. Normalized form (lowercased, trimmed) is what matching uses.
  final String name;

  /// ARGB colour value chosen when the tag was created.
  final int colorValue;

  final DateTime createdAt;

  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String get normalizedName => normalize(name);

  Tag copyWith({String? name, int? colorValue}) => Tag(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': colorValue,
    'createdAt': createdAt.toIso8601String(),
  };
}
