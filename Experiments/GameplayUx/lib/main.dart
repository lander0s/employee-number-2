import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/gameplay_screen.dart';
import 'ui/notebook/brief.dart';
import 'ui/wireframe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, in all three of the places 13.3 says it has to be locked -
  // here, AndroidManifest.xml, and (on desktop) the window shape. Locking it
  // only in Dart still lets the OS rotate during startup.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full screen, the way a game is: no status bar, no navigation bar, the whole
  // panel.
  //
  // `manual` with no overlays rather than `immersiveSticky`: this says exactly
  // which bars are wanted (none) instead of asking for a mode that keeps a
  // transient overlay alive for the ones it hides. The window shape is also
  // declared in the Android theme, so the bars are gone before Flutter starts
  // and there is no resize on launch; this keeps it that way after one.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

  // Still set, for the moment either bar is pulled back down: dark icons now,
  // because the frame under them is kraft rather than charcoal.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const GameplayUxApp());
}

/// Hardcoded for the experiment; a level file owns this in the real thing.
/// Actionable only - what the boss said, and why, is the call's job. A note you
/// wrote to yourself does not quote him back.
const _sampleBrief = LevelBrief(
  task: 'Ship only the positive numbers.',
  detail: 'Zero is not positive. Everything else goes in the bin.',
);

class GameplayUxApp extends StatelessWidget {
  const GameplayUxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee #2 - Gameplay UX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: W.page,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const GameplayScreen(brief: _sampleBrief),
    );
  }
}
