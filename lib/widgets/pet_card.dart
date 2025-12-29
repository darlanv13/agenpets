import 'package:flutter/material.dart';
import '../models/pet_model.dart';

class PetCard extends StatelessWidget {
  final PetModel pet;
  final bool isSelected;
  final VoidCallback onTap;

  const PetCard({
    Key? key,
    required this.pet,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Ícone Dinâmico baseado no tipo
            CircleAvatar(
              backgroundColor: _getColorByPetType(pet.tipo),
              child: Icon(_getIconByPetType(pet.tipo), color: Colors.white),
            ),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.nome,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "${pet.tipo} • ${pet.raca}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  IconData _getIconByPetType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'cao':
        return Icons.pets; // Ícone de pata
      case 'gato':
        return Icons.cruelty_free; // Ícone que lembra gato (ou use FontAwesome)
      default:
        return Icons.bug_report; // Genérico
    }
  }

  Color _getColorByPetType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'cao':
        return Colors.orange;
      case 'gato':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }
}
