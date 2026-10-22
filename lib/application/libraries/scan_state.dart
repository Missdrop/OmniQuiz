/// Metadata is a scan hint, never a replacement for an imported content revision.
class FileStamp {
  const FileStamp(this.origin, this.name, this.size, this.modified);
  final String origin, name;
  final int size, modified;
}

class ScanRecord {
  const ScanRecord({
    required this.name,
    this.size,
    this.modified,
    this.revision,
    this.ignored = false,
  });
  final String name;
  final int? size, modified;
  final String? revision;
  final bool ignored;

  bool matches(FileStamp file, String revision) =>
      !ignored &&
      size == file.size &&
      modified == file.modified &&
      this.revision == revision;

  Map<String, Object?> toJson() => {
    'name': name,
    'size': size,
    'modified': modified,
    'revision': revision,
    'ignored': ignored,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    name: json['name'] as String,
    size: json['size'] as int?,
    modified: json['modified'] as int?,
    revision: json['revision'] as String?,
    ignored: json['ignored'] as bool,
  );
}

abstract interface class ScanStateStore {
  Future<Map<String, ScanRecord>> load();
  Future<void> save(Map<String, ScanRecord> records);
}
