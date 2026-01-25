import 'package:agenpet/admin_web/admin_web_screen.dart';
import 'package:agenpet/screens/assinatura_screen.dart';
import 'package:agenpet/screens/minhas_agendas.dart'; // Ensure this file contains MinhasAgendasScreen
import 'package:agenpet/screens/hotel_screen.dart';
import 'package:agenpet/screens/meus_pets_screen.dart';
import 'package:agenpet/screens/perfil_screen.dart';
import 'package:agenpet/screens/profissional_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Para calendário em PT-BR
import 'firebase_options.dart'; // Gerado pelo flutterfire configure

// Import das telas
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/agendamento_screen.dart';
import 'screens/pagamento_screen.dart';
import 'screens/cadastro_screen.dart'; // Vamos criar abaixo

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase
  // Se der erro aqui, lembre de rodar: flutterfire configure
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgenPet',
      debugShowCheckedModeBanner: false,

      // Configuração de Tema (Cores do App)
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF0056D2), // Azul Petshop
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: false, // Mantém estilo clássico por enquanto
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

      // Configuração de Idioma (Para datas em Português)
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('pt', 'BR')],

      // Rotas de Navegação
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
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
        '/admin_web': (context) => AdminWebScreen(),
      },
    );
  }
}
