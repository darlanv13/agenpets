class AppConfig {
  // O ID do Tenant (Loja).
  // Inicialmente vem do ambiente, mas pode ser sobrescrito em runtime (Multi-Tenant App)
  static String _tenantId = const String.fromEnvironment(
    'TENANT_ID',
    defaultValue: 'loja_padrao',
  );

  static String get tenantId => _tenantId;

  // Permite alterar o tenantId em tempo de execução
  static void setTenantId(String id) {
    _tenantId = id;
  }

  // Nome da Loja (Opcional, para exibir na UI)
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Agen Pets',
  );
}
