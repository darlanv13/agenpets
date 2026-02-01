import 'package:agenpet/admin_tenants/widgets/tenant_team_manager.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:flutter/material.dart';

class GestaoEquipeView extends StatelessWidget {
  const GestaoEquipeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Uses the current tenant's ID
    return Scaffold(
      body: TenantTeamManager(tenantId: AppConfig.tenantId),
    );
  }
}
