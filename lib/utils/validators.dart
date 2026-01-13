class Validators {
  /// Valida se o CPF é válido (Algoritmo Módulo 11)
  static bool isCpfValido(String? cpf) {
    if (cpf == null) return false;

    // 1. Remove caracteres não numéricos
    var numeros = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Tamanho deve ser 11
    if (numeros.length != 11) return false;

    // 3. Bloqueia sequências repetidas conhecidas (ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1*$').hasMatch(numeros)) return false;

    // 4. Validação dos Dígitos Verificadores
    List<int> digitos = numeros.split('').map((d) => int.parse(d)).toList();

    // Primeiro dígito
    int calcDv1 = 0;
    for (int i = 0; i < 9; i++) {
      calcDv1 += digitos[i] * (10 - i);
    }
    int dv1 = 11 - (calcDv1 % 11);
    if (dv1 >= 10) dv1 = 0;

    if (dv1 != digitos[9]) return false;

    // Segundo dígito
    int calcDv2 = 0;
    for (int i = 0; i < 10; i++) {
      calcDv2 += digitos[i] * (11 - i);
    }
    int dv2 = 11 - (calcDv2 % 11);
    if (dv2 >= 10) dv2 = 0;

    return dv2 == digitos[10];
  }
}
