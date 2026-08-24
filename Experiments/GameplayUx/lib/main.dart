import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Android 15+ forces edge-to-edge, so the page colour shows behind the status
  // and navigation bars. Transparent bars with light icons, or the system draws
  // dark-on-dark and the clock disappears.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: W.page,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const GameplayScreen(),
    );
  }
}
