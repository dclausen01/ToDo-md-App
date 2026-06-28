import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/saf.dart';

/// Persisted app configuration.
class AppSettings {
  const AppSettings({
    this.vaultTreeUri,
    this.vaultName,
    this.boardPath = 'ToDo.md',
    this.defaultLaneTitle,
  });

  /// SAF tree URI of the Obsidian vault folder, or null if not yet chosen.
  final String? vaultTreeUri;

  /// Display name of the vault (used for obsidian:// links).
  final String? vaultName;

  /// Board file path relative to the vault root.
  final String boardPath;

  /// Title of the lane new quick-add cards go into (null = first lane).
  final String? defaultLaneTitle;

  bool get isConfigured => vaultTreeUri != null && vaultTreeUri!.isNotEmpty;

  AppSettings copyWith({
    String? vaultTreeUri,
    String? vaultName,
    String? boardPath,
    String? defaultLaneTitle,
    bool clearDefaultLane = false,
  }) {
    return AppSettings(
      vaultTreeUri: vaultTreeUri ?? this.vaultTreeUri,
      vaultName: vaultName ?? this.vaultName,
      boardPath: boardPath ?? this.boardPath,
      defaultLaneTitle:
          clearDefaultLane ? null : (defaultLaneTitle ?? this.defaultLaneTitle),
    );
  }
}

const _kVaultUri = 'vault_tree_uri';
const _kVaultName = 'vault_name';
const _kBoardPath = 'board_path';
const _kDefaultLane = 'default_lane_title';

/// Loads and persists [AppSettings].
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      vaultTreeUri: prefs.getString(_kVaultUri),
      vaultName: prefs.getString(_kVaultName),
      boardPath: prefs.getString(_kBoardPath) ?? 'ToDo.md',
      defaultLaneTitle: prefs.getString(_kDefaultLane),
    );
  }

  Future<void> _persist(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s.vaultTreeUri != null) {
      await prefs.setString(_kVaultUri, s.vaultTreeUri!);
    }
    if (s.vaultName != null) {
      await prefs.setString(_kVaultName, s.vaultName!);
    }
    await prefs.setString(_kBoardPath, s.boardPath);
    if (s.defaultLaneTitle != null) {
      await prefs.setString(_kDefaultLane, s.defaultLaneTitle!);
    } else {
      await prefs.remove(_kDefaultLane);
    }
  }

  Future<void> setVault({required String treeUri, String? name}) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(vaultTreeUri: treeUri, vaultName: name);
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> setBoardPath(String path) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(boardPath: path);
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> setDefaultLane(String? laneTitle) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = laneTitle == null
        ? current.copyWith(clearDefaultLane: true)
        : current.copyWith(defaultLaneTitle: laneTitle);
    state = AsyncData(next);
    await _persist(next);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Shared SAF service instance.
final safServiceProvider = Provider<SafService>((ref) => const SafService());
