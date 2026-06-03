class DocumentFile {
  final int? id;
  final int? documentId;
  final String encryptedFilePath;
  final String fileExtension;
  final int fileSizeBytes;

  DocumentFile({
    this.id,
    this.documentId,
    required this.encryptedFilePath,
    required this.fileExtension,
    required this.fileSizeBytes,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'document_id': documentId,
      'encryptedFilePath': encryptedFilePath,
      'fileExtension': fileExtension,
      'fileSizeBytes': fileSizeBytes,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory DocumentFile.fromMap(Map<String, dynamic> map) {
    return DocumentFile(
      id: map['id'] as int?,
      documentId: map['document_id'] as int?,
      encryptedFilePath: map['encryptedFilePath'] as String,
      fileExtension: map['fileExtension'] as String,
      fileSizeBytes: map['fileSizeBytes'] as int,
    );
  }

  DocumentFile copyWith({
    int? id,
    int? documentId,
    String? encryptedFilePath,
    String? fileExtension,
    int? fileSizeBytes,
  }) {
    return DocumentFile(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      encryptedFilePath: encryptedFilePath ?? this.encryptedFilePath,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}

class Document {
  final int? id;
  final String name;
  final String? note;
  final int categoryId;
  final List<DocumentFile> files;
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
    required this.categoryId,
    this.files = const [],
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
    int? categoryId,
    List<DocumentFile>? files,
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
      categoryId: categoryId ?? this.categoryId,
      files: files ?? this.files,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isStarred: isStarred ?? this.isStarred,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'note': note,
      'category': categoryId,
      'issueDate': issueDate?.millisecondsSinceEpoch,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isStarred': isStarred ? 1 : 0,
      'tags': tags.join(','),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Document.fromMap(Map<String, dynamic> map, {List<DocumentFile> files = const []}) {
    return Document(
      id: map['id'] as int?,
      name: map['name'] as String,
      note: map['note'] as String?,
      categoryId: map['category'] as int,
      files: files,
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
