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
import 'ui/stage.dart';

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
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => ProfileEditor(
                    joinAfterSave: state.uri.queryParameters['join'] == '1',
                  ),
                ),
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
      dividerColor: const Color(0xff352841),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xff412c4c)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: const Color(0xff100d19),
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? const Color(0xffff99f4)
                : const Color(0xffa293b1),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            color: s.contains(WidgetState.selected)
                ? const Color(0xffff99f4)
                : const Color(0xffa293b1),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: const Color(0xff67368a),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xffad6eca)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffe5cfed),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: const Color(0xff46214f),
        backgroundColor: panel,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff100d19),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
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
    final joined = ref.watch(
      liveProvider.select((_) => ref.read(liveProvider.notifier).joined),
    );
    final account = ref.watch(accountProvider);
    final ready = state.$1 == Gate.ready && account.hasValue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ink,
        actions: ready
            ? [
                Text(
                  joined ? '●  LIVE' : '●  DEMO MODE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: joined ? cyan : pink,
                  ),
                ),
                IconButton(
                  tooltip: 'プロフィール',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_outline, size: 20),
                ),
              ]
            : null,
        toolbarHeight: 56,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
        title: const Row(
          children: [
            CustomPaint(size: Size(27, 23), painter: WaveMark(cyan)),
            SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'FES'),
                  TextSpan(
                    text: 'WAVE',
                    style: TextStyle(color: Color(0xffe477fa)),
                  ),
                ],
              ),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 20,
              ),
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
                  icon: Icon(Icons.favorite_border),
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
