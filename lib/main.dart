import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/config/app_theme.dart';
import 'app/config/app_router.dart';
import 'app/config/theme_provider.dart';
import 'core/services/hive_service.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with User Config
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDh8u7DUxmv65y0aen9o0RWfgnNm9aF97s",
        authDomain: "trac-4c25b.firebaseapp.com",
        databaseURL: "https://trac-4c25b-default-rtdb.firebaseio.com",
        projectId: "trac-4c25b",
        storageBucket: "trac-4c25b.firebasestorage.app",
        messagingSenderId: "475761474645",
        appId: "1:475761474645:web:704f4d8a34f654295268dc",
        measurementId: "G-T3BTDGD3Y2",
      ),
    );
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Initialize Shared Preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Hive boxes
  await HiveService.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AntigravityApp(),
    ),
  );
}

class AntigravityApp extends ConsumerWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Expenses Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
