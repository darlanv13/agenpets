import 'package:agenpet/features/store/presentation/views/admin_web_screen.dart';
import 'package:agenpet/features/subscription/presentation/screens/assinatura_screen.dart';
import 'package:agenpet/features/scheduling/presentation/screens/minhas_agendas.dart';
import 'package:agenpet/features/hotel/presentation/screens/hotel_screen.dart';
import 'package:agenpet/features/creche/presentation/screens/creche_screen.dart';
import 'package:agenpet/features/pets/presentation/screens/meus_pets_screen.dart';
import 'package:agenpet/features/auth/presentation/screens/perfil_screen.dart';
import 'package:agenpet/features/professional/presentation/views/profissional_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:agenpet/core/config/firebase_options.dart';
import 'package:agenpet/core/config/app_config.dart';

import 'package:agenpet/features/auth/presentation/screens/login_screen.dart';
import 'package:agenpet/features/professional/presentation/views/login_profissional_screen.dart';
import 'package:agenpet/features/auth/presentation/screens/home_screen.dart';
import 'package:agenpet/features/scheduling/presentation/screens/agendamento_screen.dart';
import 'package:agenpet/features/payment/presentation/screens/pagamento_screen.dart';
import 'package:agenpet/features/auth/presentation/screens/cadastro_screen.dart';

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
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF0056D2),
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: false,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF0056D2),
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0056D2),
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
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/login_profissional': (context) => LoginProfissionalScreen(),
        '/cadastro': (context) => CadastroScreen(),
        '/home': (context) => HomeScreen(),
        '/agendamento': (context) => AgendamentoScreen(),
        '/pagamento': (context) => PagamentoScreen(),
        '/profissional': (context) => ProfissionalScreen(),
        '/meus_pets': (context) => MeusPetsScreen(),
        '/perfil': (context) => PerfilScreen(),
        '/assinatura': (context) => AssinaturaScreen(),
        '/minhas_agendas': (context) => MinhasAgendas(userCpf: ''),
        '/hotel': (context) => HotelScreen(),
        '/creche': (context) => CrecheScreen(),
        '/admin_web': (context) => AdminWebScreen(),
      },
    );
  }
}
