import 'package:flutter/material.dart';
import 'package:agenpet/config/app_config.dart';
import 'package:agenpet/admin_tenants/widgets/tenant_team_manager.dart';

class GestaoEquipeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: TenantTeamManager(tenantId: AppConfig.tenantId),
    );
  }
}
