class TrackedFile {
  final String id;
  final String filePath;
  final String fileName;
  final String? repoPath;
  final DateTime addedAt;
  final DateTime? lastAccessedAt;

  const TrackedFile({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.repoPath,
    required this.addedAt,
    this.lastAccessedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'repoPath': repoPath,
      'addedAt': addedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
    };
  }

  factory TrackedFile.fromMap(Map<String, dynamic> map) {
    return TrackedFile(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      repoPath: map['repoPath'] as String?,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastAccessedAt: map['lastAccessedAt'] != null
          ? DateTime.parse(map['lastAccessedAt'] as String)
          : null,
    );
  }

  TrackedFile copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? repoPath,
    DateTime? addedAt,
    DateTime? lastAccessedAt,
  }) {
    return TrackedFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      repoPath: repoPath ?? this.repoPath,
      addedAt: addedAt ?? this.addedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}
