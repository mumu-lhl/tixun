import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_service.dart';

/// The app host replaces the entire provider scope when restoring. A screen
/// cannot safely replace its own open database and cached consumers.
class BackupActions {
  const BackupActions({
    required this.export,
    required this.prepare,
    required this.prepareUndo,
    required this.restore,
    required this.clearUndo,
  });
  final Future<void> Function() export;
  final Future<void> Function() clearUndo;
  final Future<PreparedBackup> Function(File) prepare;
  final Future<PreparedBackup> Function() prepareUndo;
  final Future<void> Function(PreparedBackup) restore;
}

final backupActionsProvider = Provider<BackupActions?>((ref) => null);
