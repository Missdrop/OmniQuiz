/// Identity and material location; the app keeps each library's database private.
class StudyLibrary {
  const StudyLibrary({
    required this.id,
    required this.name,
    required this.directory,
  });
  final String id, name, directory;
  bool get legacy => id == 'default';
}
