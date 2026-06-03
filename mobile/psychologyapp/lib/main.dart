import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_register_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
const _storage = FlutterSecureStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization warning: $e");
  }

  // Kayıtlı temayı yükle
  final savedTheme = await _storage.read(key: 'theme_mode');
  if (savedTheme == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else {
    themeNotifier.value = ThemeMode.dark;
  }

  runApp(const PsikolojiApp());
}

class PsikolojiApp extends StatelessWidget {
  const PsikolojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Psikoloji App',
          themeMode: themeNotifier.value,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5C6BC0),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F5FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F1026),
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5C6BC0),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F1026), // Ultra deep night blue
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1F3B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1F3B),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),

          initialRoute: '/',
          routes: {
            '/': (context) => const ProfileRegisterScreen(),
            ChatScreen.routeName: (context) => const ChatScreen(),
          },
        );
      },
    );
  }
}
