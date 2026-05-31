enum DocumentCategory {
  identity,
  vehicle,
  medical,
  education,
  finance,
  property,
  other,
}

extension DocumentCategoryX on DocumentCategory {
  String get label {
    switch (this) {
      case DocumentCategory.identity:  return 'Identity';
      case DocumentCategory.vehicle:   return 'Vehicle';
      case DocumentCategory.medical:   return 'Medical';
      case DocumentCategory.education: return 'Education';
      case DocumentCategory.finance:   return 'Finance';
      case DocumentCategory.property:  return 'Property';
      case DocumentCategory.other:     return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DocumentCategory.identity:  return '🪪';
      case DocumentCategory.vehicle:   return '🚗';
      case DocumentCategory.medical:   return '🏥';
      case DocumentCategory.education: return '🎓';
      case DocumentCategory.finance:   return '💳';
      case DocumentCategory.property:  return '🏠';
      case DocumentCategory.other:     return '📄';
    }
  }

  int get dbValue {
    return DocumentCategory.values.indexOf(this);
  }

  static DocumentCategory fromDb(int value) {
    return DocumentCategory.values[value];
  }
}

class Document {
  final int? id;
  final String name;
  final String? note;
  final DocumentCategory category;
  final String encryptedFilePath;
  final String fileExtension;
  final int fileSizeBytes;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isStarred;
  final List<String> tags;

  Document({
    this.id,
    required this.name,
    this.note,
    required this.category,
    required this.encryptedFilePath,
    required this.fileExtension,
    required this.fileSizeBytes,
    this.issueDate,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    this.isStarred = false,
    this.tags = const [],
  });

  Document copyWith({
    int? id,
    String? name,
    String? note,
    DocumentCategory? category,
    String? encryptedFilePath,
    String? fileExtension,
    int? fileSizeBytes,
    DateTime? issueDate,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isStarred,
    List<String>? tags,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      category: category ?? this.category,
      encryptedFilePath: encryptedFilePath ?? this.encryptedFilePath,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isStarred: isStarred ?? this.isStarred,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'note': note,
      'category': category.dbValue,
      'encryptedFilePath': encryptedFilePath,
      'fileExtension': fileExtension,
      'fileSizeBytes': fileSizeBytes,
      'issueDate': issueDate?.millisecondsSinceEpoch,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isStarred': isStarred ? 1 : 0,
      'tags': tags.join(','),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int?,
      name: map['name'] as String,
      note: map['note'] as String?,
      category: DocumentCategoryX.fromDb(map['category'] as int),
      encryptedFilePath: map['encryptedFilePath'] as String,
      fileExtension: map['fileExtension'] as String,
      fileSizeBytes: map['fileSizeBytes'] as int,
      issueDate: map['issueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['issueDate'] as int)
          : null,
      expiryDate: map['expiryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate'] as int)
          : null,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      isStarred: (map['isStarred'] as int) == 1,
      tags: (map['tags'] as String).isEmpty
          ? []
          : (map['tags'] as String).split(','),
    );
  }
}
