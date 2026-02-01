import 'package:flutter/services.dart';

class Formatters {
  // --- MÉTODOS PARA EXIBIÇÃO (String -> String) ---

  static String cpf(String? cpf) {
    if (cpf == null || cpf.isEmpty) return "";
    var nums = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (nums.length != 11) {
      return cpf; // Retorna original se não tiver 11 dígitos
    }
    return "${nums.substring(0, 3)}.${nums.substring(3, 6)}.${nums.substring(6, 9)}-${nums.substring(9, 11)}";
  }

  static String telefone(String? tel) {
    if (tel == null || tel.isEmpty) return "";
    var nums = tel.replaceAll(RegExp(r'[^0-9]'), '');

    if (nums.length == 11) {
      // Celular: (11) 91234-5678
      return "(${nums.substring(0, 2)}) ${nums.substring(2, 7)}-${nums.substring(7, 11)}";
    } else if (nums.length == 10) {
      // Fixo: (11) 1234-5678
      return "(${nums.substring(0, 2)}) ${nums.substring(2, 6)}-${nums.substring(6, 10)}";
    }
    return tel;
  }
}

// --- MÁSCARAS PARA INPUTS (TextField) ---

/// Máscara de CPF: 000.000.000-00
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 11) text = text.substring(0, 11);

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Máscara de Telefone: (00) 00000-0000 ou (00) 0000-0000
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 11) text = text.substring(0, 11);

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');

      // Hífen dinâmico (muda de posição se for fixo ou celular)
      if (text.length == 11) {
        if (i == 7) buffer.write('-');
      } else {
        if (i == 6) buffer.write('-');
      }

      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
