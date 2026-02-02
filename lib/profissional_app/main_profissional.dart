import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:agenpet/firebase_options.dart';
import 'package:agenpet/profissional_app/login_profissional_screen.dart';
import 'package:agenpet/profissional_app/profissional_screen.dart';
import 'package:agenpet/painel_loja_web/admin_web_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgenPet Profissional',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        primaryColor: Color(0xFF4A148C), // _corAcai
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: false,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF4A148C),
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A148C),
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('pt', 'BR')],
      initialRoute: '/',
      routes: {
        '/': (context) => LoginProfissionalScreen(),
        '/profissional': (context) => ProfissionalScreen(),
        '/admin_web': (context) => AdminWebScreen(),
      },
    );
  }
}
