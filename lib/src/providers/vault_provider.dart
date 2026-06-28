import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/link_resolver.dart';
import '../storage/saf.dart';
import 'settings_provider.dart';

/// Lists every file in the vault tree (recursive). Cached until invalidated;
/// used to resolve `[[wikilinks]]`.
final vaultFilesProvider = FutureProvider<List<SafFile>>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  if (!settings.isConfigured) return const [];
  final saf = ref.read(safServiceProvider);
  return saf.listFiles(settings.vaultTreeUri!);
});

/// A [LinkResolver] built from the current vault file list.
final linkResolverProvider = Provider<LinkResolver>((ref) {
  final files = ref.watch(vaultFilesProvider).valueOrNull ?? const <SafFile>[];
  return LinkResolver(files);
});
