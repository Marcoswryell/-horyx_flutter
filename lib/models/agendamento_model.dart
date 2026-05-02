class Agendamento {
  String? id;
  String idCliente;
  String idServico;
  String idProfissional;
  DateTime dataHora;
  String status; // 'pendente', 'confirmado', 'concluido', 'cancelado'

  Agendamento({
    this.id,
    required this.idCliente,
    required this.idServico,
    required this.idProfissional,
    required this.dataHora,
    this.status = 'pendente',
  });

  // Converte do Firestore para o App
  factory Agendamento.fromMap(Map<String, dynamic> map, String documentId) {
    return Agendamento(
      id: documentId,
      idCliente: map['idCliente'] ?? '',
      idServico: map['idServico'] ?? '',
      idProfissional: map['idProfissional'] ?? '',
      dataHora: map['dataHora'].toDate(),
      status: map['status'] ?? 'pendente',
    );
  }

  // Converte do App para o Firestore
  Map<String, dynamic> toMap() {
    return {
      'idCliente': idCliente,
      'idServico': idServico,
      'idProfissional': idProfissional,
      'dataHora': dataHora,
      'status': status,
    };
  }
}
