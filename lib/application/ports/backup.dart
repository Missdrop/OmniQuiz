/// Data operations are independent of the operating system's file dialogs.
abstract interface class BackupPort {
  Future<int> exportTo(String output);
  Future<int> restoreFrom(String input);
}

abstract interface class BackupActions {
  /// Returns missing-original count, or null when the save dialog is cancelled.
  Future<int?> export();

  /// Returns restored-library count, or null when the picker is cancelled.
  Future<int?> restore();
}
