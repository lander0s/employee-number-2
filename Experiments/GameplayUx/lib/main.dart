import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model/levels.dart';
import 'ui/gameplay_screen.dart';
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
  // because the frame under them is light rather than charcoal.
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
      // Straight into gameplay. There is no menu, no call and no progression
      // in this experiment: it opens on the one level and that is the whole
      // app (see model/levels.dart), with its solution already on the page so
      // that RUN does something on the first tap.
      home: GameplayScreen(level: levels.first, program: referenceSolution()),
    );
  }
}
