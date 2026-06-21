// One-shot launch wiring for [SceneMigratorV2] against the live Isar database.
//
// Called once from main() after the database is open. It is gated (runs only
// while AppMeta.schemaVersion < 2), non-destructive (reads legacy `.ink` +
// NotePage.shapes/importedContents, never deletes them) and idempotent, so it is
// safe to call on every launch. The migrator's logic is unit-tested with
// in-memory doubles; this is the thin production binding.

import 'package:flutter/foundation.dart';

import '../persistence/isar_scene_element_store.dart';
import 'legacy_page_source.dart';
import 'migration_gate.dart';
import 'scene_migrator.dart';

/// Runs the v1→v2 migration if needed. Never throws: a migration failure must
/// not block app start (legacy data is untouched and the app keeps working on
/// the old screens). Returns true if the migration actually ran.
Future<bool> runLaunchMigration() async {
  try {
    final migrator = SceneMigratorV2(
      source: IsarLegacyPageSource(),
      store: IsarSceneElementStore(),
      gate: IsarMigrationGate(),
    );
    return await migrator.run();
  } catch (e, st) {
    debugPrint('Scene migration skipped (non-fatal): $e\n$st');
    return false;
  }
}
