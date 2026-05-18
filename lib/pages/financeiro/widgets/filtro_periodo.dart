import 'package:flutter/material.dart';

class FiltroPeriodoButton extends StatefulWidget {
  final String label;
  final String value;
  final String periodoAtual;
  final VoidCallback onTap;

  const FiltroPeriodoButton({
    super.key,
    required this.label,
    required this.value,
    required this.periodoAtual,
    required this.onTap,
  });

  @override
  State<FiltroPeriodoButton> createState() => _FiltroPeriodoButtonState();
}

class _FiltroPeriodoButtonState extends State<FiltroPeriodoButton> {
  DateTimeRange? range;
  DateTime? singleDate;

  String get displayText {
    if (singleDate != null) {
      return "${singleDate!.day}/${singleDate!.month}/${singleDate!.year}";
    }
    if (range != null) {
      final start = range!.start;
      final end = range!.end;
      return "${start.day}/${start.month} - ${end.day}/${end.month}";
    }
    return widget.label;
  }

  Future<void> _openCalendar() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() {
      range = picked;
    });

    widget.onTap();
  }

  Future<void> _openDayPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() {
      singleDate = picked;
      range = null;
    });

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool ativo = widget.periodoAtual == widget.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (widget.value == 'custom') {
              _openCalendar();
            } else if (widget.value == 'day') {
              _openDayPicker();
            } else {
              widget.onTap();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: ativo
                  ? LinearGradient(
                      colors: [
                        Colors.blueAccent,
                        Colors.blue.shade700,
                      ],
                    )
                  : null,
              color: ativo ? null : const Color.fromARGB(255, 0, 0, 0).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ativo
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(0.08),
              ),
              boxShadow: ativo
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.value == 'custom' ? displayText : widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                    color: ativo ? Colors.white : const Color.fromARGB(179, 0, 0, 0),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}