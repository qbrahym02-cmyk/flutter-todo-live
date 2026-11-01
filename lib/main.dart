import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/remote_config.dart';
import 'services/task_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TaskStore();
  final remote = RemoteConfigService();
  await Future.wait([store.load(), remote.init()]);
  runApp(TodoApp(store: store, remote: remote));
}

class TodoApp extends StatelessWidget {
  final TaskStore store;
  final RemoteConfigService remote;
  const TodoApp({super.key, required this.store, required this.remote});

  @override
  Widget build(BuildContext context) {
    // كل ما تتغير الإعدادات البعيدة يعاد بناء التطبيق بالألوان/النصوص الجديدة.
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        final cfg = remote.config;
        ThemeData theme(Brightness b) => ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: cfg.primaryColor, brightness: b),
              useMaterial3: true,
            );
        return MaterialApp(
          title: cfg.appTitle,
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          themeMode: cfg.themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeScreen(store: store, remote: remote),
        );
      },
    );
  }
}
