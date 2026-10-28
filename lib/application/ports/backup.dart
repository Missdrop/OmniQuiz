// Separates backup data operations from operating-system save and open dialogs.

/// Data operations are independent of the operating system's file dialogs.
abstract interface class BackupPort {
  /// Writes a portable snapshot and returns the number of unavailable original files.
  Future<int> exportTo(String output);

  /// Creates independent library copies and returns their count after catalog publication.
  Future<int> restoreFrom(String input);
}

/// UI-facing picker adapter; null results are deliberate user cancellations.
abstract interface class BackupActions {
  /// Returns missing-original count, or null when the save dialog is cancelled.
  Future<int?> export();

  /// Returns restored-library count, or null when the picker is cancelled.
  Future<int?> restore();
}
