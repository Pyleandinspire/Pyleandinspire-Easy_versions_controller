class Snapshot {
  final String id;
  final String fileId;
  final String snapshotPath;
  final DateTime timestamp;
  final int fileSize;
  final String? sha256Hash;
  final String? message;

  const Snapshot({
    required this.id,
    required this.fileId,
    required this.snapshotPath,
    required this.timestamp,
    required this.fileSize,
    this.sha256Hash,
    this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'snapshotPath': snapshotPath,
      'timestamp': timestamp.toIso8601String(),
      'fileSize': fileSize,
      'sha256Hash': sha256Hash,
      'message': message,
    };
  }

  factory Snapshot.fromMap(Map<String, dynamic> map) {
    return Snapshot(
      id: map['id'] as String,
      fileId: map['fileId'] as String,
      snapshotPath: map['snapshotPath'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      fileSize: map['fileSize'] as int,
      sha256Hash: map['sha256Hash'] as String?,
      message: map['message'] as String?,
    );
  }

  Snapshot copyWith({
    String? id,
    String? fileId,
    String? snapshotPath,
    DateTime? timestamp,
    int? fileSize,
    String? sha256Hash,
    String? message,
  }) {
    return Snapshot(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      snapshotPath: snapshotPath ?? this.snapshotPath,
      timestamp: timestamp ?? this.timestamp,
      fileSize: fileSize ?? this.fileSize,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      message: message ?? this.message,
    );
  }
}