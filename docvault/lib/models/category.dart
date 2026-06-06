class Category {
  final int? id;
  final String name;
  final String icon;
  final int sortOrder;

  Category({
    this.id,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
