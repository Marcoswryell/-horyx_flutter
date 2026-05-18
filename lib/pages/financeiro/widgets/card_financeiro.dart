import 'package:flutter/material.dart';
import 'dart:math';

class FinanceiroCard extends StatefulWidget {
  final String titulo;
  final double valor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final double? valorMesAnterior;

  const FinanceiroCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.valorMesAnterior,
  });

  @override
  State<FinanceiroCard> createState() => _FinanceiroCardState();
}

class _FinanceiroCardState extends State<FinanceiroCard> {
  bool expanded = false;

  double get growth {
    final old = widget.valorMesAnterior ?? 0;
    if (old == 0) return 0;
    return ((widget.valor - old) / old) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            expanded = !expanded;
          });
          if (widget.onTap != null) widget.onTap!();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.valor),
                duration: const Duration(milliseconds: 700),
                builder: (context, value, child) {
                  return Text(
                    "R\$ ${value.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: widget.valor >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final double base = widget.valor.abs();
                    final double heightFactor = ((base % (index + 1)) + 1) / 5;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 3,
                      height: 4 + (heightFactor * 10),
                      decoration: BoxDecoration(
                        color: widget.valor >= 0 ? Colors.greenAccent : Colors.redAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      Text(
                        "Crescimento: ${growth.toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: growth >= 0 ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Mês anterior: R\$ ${widget.valorMesAnterior?.toStringAsFixed(2) ?? "0.00"}",
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 30,
                        child: CustomPaint(
                          painter: _SimpleLineChartPainter(widget.valorMesAnterior ?? 0, widget.valor),
                          child: Container(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


Widget _card(String titulo, double valor, IconData icon, Color iconColor, {VoidCallback? onTap, double? valorMesAnterior}) {
  double growth = 0;
  if (valorMesAnterior != null && valorMesAnterior != 0) {
    growth = ((valor - valorMesAnterior) / valorMesAnterior) * 100;
  }
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: valor),
              duration: const Duration(milliseconds: 700),
              builder: (context, value, child) {
                return Text(
                  "R\$ ${value.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: valor >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final double base = valor.abs();
                  final double heightFactor = ((base % (index + 1)) + 1) / 5;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: 4 + (heightFactor * 10),
                    decoration: BoxDecoration(
                      color: valor >= 0 ? Colors.greenAccent : Colors.redAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%",
              style: TextStyle(
                color: growth >= 0 ? Colors.greenAccent : Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


class _SimpleLineChartPainter extends CustomPainter {
  final double oldValue;
  final double newValue;

  _SimpleLineChartPainter(this.oldValue, this.newValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    final startY = size.height * 0.7;
    final endY = size.height * (1 - (newValue / (newValue + oldValue + 1)));

    path.moveTo(0, startY);
    path.lineTo(size.width, endY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}