import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'live/live_page.dart';
import 'live/session.dart';
import 'profile/pages.dart';
import 'memories/page.dart';
import 'services.dart';
import 'ui/shared.dart';

void main() => runApp(const ProviderScope(child: Feswave()));
final router = GoRouter(
  initialLocation: '/live',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/live', builder: (_, _) => const LivePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/memories', builder: (_, _) => const MemoriesPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfilePage(),
              routes: [
                GoRoute(path: 'edit', builder: (_, _) => const ProfileEditor()),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class Feswave extends StatelessWidget {
  const Feswave({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'FESWAVE',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: lilac,
        brightness: Brightness.dark,
      ).copyWith(primary: lilac, surface: panel),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
  );
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      liveProvider.select((_) {
        final s = ref.read(liveProvider.notifier);
        return (s.gate, s.message, s.busy);
      }),
    );
    final account = ref.watch(accountProvider);
    final ready = state.$1 == Gate.ready && account.hasValue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        title: const Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: cyan),
            SizedBox(width: 8),
            Text(
              'FESWAVE',
              style: TextStyle(letterSpacing: 1.8, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ready
            ? widget.shell
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.$1 == Gate.blocked) ...[
                        const Icon(
                          Icons.bluetooth_disabled,
                          size: 44,
                          color: lilac,
                        ),
                        Text(state.$2, textAlign: TextAlign.center),
                        FilledButton(
                          onPressed: state.$3
                              ? null
                              : () => ref.read(liveProvider.notifier).check(),
                          child: const Text('再確認'),
                        ),
                        TextButton(
                          onPressed: openAppSettings,
                          child: const Text('設定を開く'),
                        ),
                      ] else if (account.hasError)
                        Text('端末データを開けません · ${account.error}')
                      else
                        const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: ready
          ? NavigationBar(
              selectedIndex: widget.shell.currentIndex,
              onDestinationSelected: widget.shell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.graphic_eq),
                  label: 'ライブ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: 'メモリ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'プロフィール',
                ),
              ],
            )
          : null,
    );
  }
}
