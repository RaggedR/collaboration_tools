import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/router.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

/// Root application widget.
class CollaborationToolsApp extends ConsumerStatefulWidget {
  const CollaborationToolsApp({super.key});

  @override
  ConsumerState<CollaborationToolsApp> createState() =>
      _CollaborationToolsAppState();
}

class _CollaborationToolsAppState
    extends ConsumerState<CollaborationToolsApp> {
  @override
  void initState() {
    super.initState();
    // Restore session from stored token on cold start.
    Future.microtask(() {
      ref.read(authProvider.notifier).checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final schemaAsync = ref.watch(schemaProvider);
    // Load schema once after authentication.
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        ref.read(schemaProvider.notifier).load();
      }
    });

    final themeColor = schemaAsync.valueOrNull?.app.themeColor;

    return MaterialApp.router(
      title: schemaAsync.valueOrNull?.app.name ?? 'Collaboration Tools',
      theme: AppTheme.light(themeColor: themeColor),
      darkTheme: AppTheme.dark(themeColor: themeColor),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
