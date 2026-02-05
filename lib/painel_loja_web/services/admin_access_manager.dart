import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/services/app_database.dart';

// Imports das Views
import '../views/dashboard_view.dart';
import '../views/banho_tosa_view.dart';
import '../views/hotel_view.dart';
import '../views/gestao_precos_view.dart';
import '../views/configuracao_agenda_view.dart';
import '../views/venda_assinatura_view.dart';
import '../views/gestao_banners_view.dart';
import '../views/pdv_view.dart';
import '../views/creche_view.dart';
import '../views/gestao_estoque_view.dart';
import 'package:agenpet/painel_admin_tenants/views/gestao_tenants_view.dart';

class AdminModule {
  final String id;
  final String title;
  final IconData icon;
  final String? section;
  final Widget widget;

  AdminModule({
    required this.id,
    required this.title,
    required this.icon,
    this.section,
    required this.widget,
  });
}

class AdminAccessManager {
  // Singleton Pattern (Opcional, mas útil se quisermos cachear algo no futuro)
  static final AdminAccessManager _instance = AdminAccessManager._internal();
  factory AdminAccessManager() => _instance;
  AdminAccessManager._internal();

  /// Carrega as permissões e módulos acessíveis de forma otimizada (Paralela)
  Future<List<AdminModule>> getAccessibleModules(User user) async {
    bool isMaster = false;
    List<String> userAcessos = [];
    Map<String, dynamic> tenantConfig = {};

    try {
      final db = AppDatabase.instance;

      // 1. Definição das Tarefas (Paralelas)
      // Task A: User Profile (Permissions)
      final profileTask = db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('profissionais')
          .doc(user.uid)
          .get();

      // Task B: Tenant Config (Enabled Modules)
      final configTask = db
          .collection('tenants')
          .doc(AppConfig.tenantId)
          .collection('config')
          .doc('parametros')
          .get();

      // Task C: Claims (Token) - Já é rápido, mas podemos fazer junto ou antes
      // Vamos fazer antes pq é local/cacheado geralmente
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;

      if (claims != null && claims['acessos'] != null) {
        userAcessos = List<String>.from(claims['acessos']);
        if (claims['master'] == true) isMaster = true;
      }

      // 2. Executar Fetchs do Firestore
      final results = await Future.wait([profileTask, configTask]);

      final profileSnap = results[0];
      final configSnap = results[1];

      // 3. Processar Perfil (Fallback/Complemento)
      if (profileSnap.exists) {
        final data = profileSnap.data()!;
        if (data['perfil'] == 'master') isMaster = true;

        // Se não veio nos claims, pega do banco
        if (userAcessos.isEmpty && data['acessos'] != null) {
          userAcessos = List<String>.from(data['acessos']);
        }
      }

      // 4. Processar Config
      if (configSnap.exists) {
        tenantConfig = configSnap.data()!;
      }

      // 5. Garantir acesso mínimo
      if (isMaster) {
        // Master tem acesso a tudo, não precisa verificar lista
      } else {
        if (userAcessos.isEmpty) {
          userAcessos.add('dashboard');
        }
      }
    } catch (e) {
      print("Erro ao carregar acessos (AdminAccessManager): $e");
      // Fallback de segurança
      if (userAcessos.isEmpty) userAcessos.add('dashboard');
    }

    return _buildModuleList(isMaster, userAcessos, tenantConfig);
  }

  /// Constrói a lista final baseada nas regras
  List<AdminModule> _buildModuleList(
    bool isMaster,
    List<String> acessos,
    Map<String, dynamic> config,
  ) {
    // Flags de Configuração (Features Toggles)
    bool temPdv = config['tem_pdv'] ?? false;
    bool temBanhoTosa = config['tem_banho_tosa'] ?? true;
    bool temHotel = config['tem_hotel'] ?? false;
    bool temCreche = config['tem_creche'] ?? false;

    // Lista Mestra de Todos os Módulos Possíveis
    final allModules = [
      AdminModule(
        id: 'dashboard',
        title: "Dashboard",
        icon: Icons.space_dashboard_rounded,
        section: "PRINCIPAL",
        widget: DashboardView(),
      ),
      if (temPdv)
        AdminModule(
          id: 'loja_pdv',
          title: "PDV / Caixa",
          icon: FontAwesomeIcons.cashRegister,
          widget: PdvView(isMaster: isMaster),
        ),
      if (temBanhoTosa)
        AdminModule(
          id: 'banhos_tosa',
          title: "Banhos & Tosa",
          icon: FontAwesomeIcons.scissors,
          widget: BanhosTosaView(),
        ),
      if (temHotel)
        AdminModule(
          id: 'hotel',
          title: "Hotel & Estadia",
          icon: FontAwesomeIcons.hotel,
          widget: HotelView(),
        ),
      if (temCreche)
        AdminModule(
          id: 'creche',
          title: "Creche",
          icon: FontAwesomeIcons.dog,
          widget: CrecheView(),
        ),
      AdminModule(
        id: 'venda_planos',
        title: "Venda de Planos",
        icon: FontAwesomeIcons.cartShopping,
        section: "VENDAS & PRODUTOS",
        widget: VendaAssinaturaView(),
      ),
      AdminModule(
        id: 'gestao_precos',
        title: "Tabela de Preços",
        icon: Icons.price_change_rounded,
        widget: GestaoPrecosView(),
      ),
      AdminModule(
        id: 'banners_app',
        title: "Banners do App",
        icon: Icons.view_carousel_rounded,
        widget: GestaoBannersView(),
      ),
      AdminModule(
        id: 'configuracoes',
        title: "Configurações",
        icon: Icons.settings_rounded,
        widget: ConfiguracaoAgendaView(),
      ),
      AdminModule(
        id: 'gestao_estoque',
        title: "Gestão de Estoque",
        icon: Icons.inventory_rounded,
        widget: GestaoEstoqueView(),
      ),
      AdminModule(
        id: 'gestao_tenants',
        title: "Gestão Multi-Tenants",
        icon: FontAwesomeIcons.building,
        section: "SUPER ADMIN",
        widget: GestaoTenantsView(),
      ),
    ];

    if (isMaster) {
      return allModules;
    }

    return allModules.where((module) => acessos.contains(module.id)).toList();
  }
}
