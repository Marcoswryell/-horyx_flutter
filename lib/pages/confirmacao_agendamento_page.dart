import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ConfirmacaoAgendamentoPage extends StatelessWidget {
  final String nome;
  final String telefone;
  final String servico;
  final DateTime data;
  final String status;
  final String? logoUrl;

  const ConfirmacaoAgendamentoPage({
    super.key,
    required this.nome,
    required this.telefone,
    required this.servico,
    required this.data,
    required this.status,
    this.logoUrl,
  });

  String formatarData(DateTime d) {
    return "${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} • ${d.hour}:${d.minute.toString().padLeft(2,'0')}";
  }

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'cancelado':
        return Colors.red;
      case 'finalizado':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'cancelado':
        return Icons.close;
      case 'finalizado':
        return Icons.check;
      default:
        return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 251),
        title: Image.asset(
          'assets/horix2.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // LOGO
            logoUrl != null && logoUrl!.isNotEmpty
                ? Image.network(
                    logoUrl!,
                    height: 80,
                    fit: BoxFit.contain,
                  )
                : const SizedBox(),

            const SizedBox(height: 10),

            // STATUS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(getStatusIcon(), size: 40, color: color),
                  const SizedBox(height: 10),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Transform.translate(
              offset: const Offset(0, 39),
              child: SizedBox(
                height: 170,
                width: 400,
                child: Lottie.asset(
                  'assets/lottie/Schedule.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // CARD PRINCIPAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _item("Cliente", nome),
                  _item("Telefone", telefone),
                  _item("Serviço", servico),
                  _item("Data", formatarData(data)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // AVISO
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                "Você pode acompanhar o status do seu agendamento. Caso o estabelecimento confirme, finalize ou cancele, essa informação será atualizada.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // BOTÃO
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.white
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Voltar"), 
                                  
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}