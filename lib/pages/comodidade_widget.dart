import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComodidadeWidget extends StatelessWidget {
  final String tenantId;

  const ComodidadeWidget({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('config')
          .doc('comodidades')
          .snapshots(),
      builder: (context, snapshot) {
        final dataMap = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final List<String> comodidades = [];
        if (dataMap['wifi'] == true) comodidades.add('wifi');
        if (dataMap['arCondicionado'] == true) comodidades.add('ar condicionado');
        if (dataMap['estacionamento'] == true) comodidades.add('estacionamento');
        if (dataMap['tv'] == true) comodidades.add('tv');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Comodidades',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            const SizedBox(height: 6),
            const Divider(height: 20),
            const SizedBox(height: 10),

            comodidades.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sem comodidades cadastradas',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : Center(
                    child: SizedBox(
                      height: 70,
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: comodidades.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = comodidades[index].toString();

                          IconData icon;

                          switch (item.toLowerCase()) {
                            case 'wifi':
                              icon = Icons.wifi;
                              break;
                            case 'ar condicionado':
                            case 'ar-condicionado':
                              icon = Icons.ac_unit;
                              break;
                            case 'estacionamento':
                              icon = Icons.local_parking;
                              break;
                            case 'tv':
                              icon = Icons.tv;
                              break;
                            default:
                              icon = Icons.check;
                          }

                          return Container(
                            width: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: const Color.fromARGB(255, 0, 0, 0), size: 20),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(179, 4, 4, 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

            const SizedBox(height: 18),

            const Text(
              'Formas de pagamento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),

            const SizedBox(height: 6),

            const Divider(),

            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 20),
                  Image.asset('assets/icons/pix1.png', width: 24),
                  const SizedBox(width: 20),
                  Image.asset('assets/icons/visa.png', width: 32),
                  const SizedBox(width: 20),
                  Image.asset('assets/icons/card.png', width: 32),
                  const SizedBox(width: 20),
                  Image.asset('assets/icons/save-money.png', width: 32),
                  const SizedBox(width: 12),
                ],
              ),
            ),

            const Divider(height: 30),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}