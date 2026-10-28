// Identifies a subject workspace without depending on UI, SQL or platform file pickers.

/// Identity and material location; portable state lives inside its .omniquiz folder.
class StudyLibrary {
  const StudyLibrary({
    required this.id,
    required this.name,
    required this.directory,
  });
  final String id, name, directory;
  bool get legacy => id == 'default';
}
