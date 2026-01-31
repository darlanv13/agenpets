class AppConfig {
  // O ID do Tenant (Loja).
  // Em desenvolvimento, usamos 'loja_padrao'.
  // Em produção, isso virá do comando de build: flutter build apk --dart-define=TENANT_ID=pet_shop_bairro
  static const String tenantId = String.fromEnvironment(
    'TENANT_ID',
    defaultValue: 'loja_padrao',
  );

  // Nome da Loja (Opcional, para exibir na UI)
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Agen Pets',
  );
}
