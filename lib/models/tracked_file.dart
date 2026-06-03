class TrackedFile {
  final String id;
  final String filePath;
  final String fileName;
  final String? snapshotDir;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TrackedFile({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.snapshotDir,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'snapshotDir': snapshotDir,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TrackedFile.fromMap(Map<String, dynamic> map) {
    return TrackedFile(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      snapshotDir: map['snapshotDir'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  TrackedFile copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? snapshotDir,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrackedFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      snapshotDir: snapshotDir ?? this.snapshotDir,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}