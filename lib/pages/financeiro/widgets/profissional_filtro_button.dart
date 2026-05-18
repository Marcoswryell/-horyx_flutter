import 'package:flutter/material.dart';

class ProfissionalFiltroButton extends StatelessWidget {
  final String nome;
  final String id;
  final String profissionalAtual;
  final VoidCallback onTap;

  const ProfissionalFiltroButton({
    super.key,
    required this.nome,
    required this.id,
    required this.profissionalAtual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = profissionalAtual == id;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: ativo
              ? Colors.blueAccent
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          nome,
          style: TextStyle(
            color: ativo
                ? Colors.white
                : Colors.black,
          ),
        ),
      ),
    );
  }
}