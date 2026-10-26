import 'dart:math';

import 'package:flutter/material.dart';

class PorcionDona {
  final double valor;
  final Color color;

  const PorcionDona(this.valor, this.color);
}

/// Gráfico circular con un hueco en el centro donde va [centro].
class GraficoDona extends StatelessWidget {
  final List<PorcionDona> porciones;
  final Widget centro;
  final double tamano;

  const GraficoDona({super.key, required this.porciones, required this.centro, this.tamano = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _PintorDona(porciones, Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(child: centro),
      ),
    );
  }
}

class _PintorDona extends CustomPainter {
  final List<PorcionDona> porciones;
  final Color fondo;

  _PintorDona(this.porciones, this.fondo);

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.14;
    final rect = Rect.fromLTWH(grosor / 2, grosor / 2, size.width - grosor, size.height - grosor);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    final total = porciones.fold<double>(0, (s, p) => s + p.valor);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * pi, false, pincel..color = fondo);
      return;
    }
    var inicio = -pi / 2;
    const separacion = 0.015;
    for (final p in porciones) {
      final barrido = p.valor / total * 2 * pi;
      final hueco = porciones.length > 1 && barrido > separacion * 2 ? separacion : 0.0;
      canvas.drawArc(rect, inicio + hueco, barrido - hueco * 2, false, pincel..color = p.color);
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(_PintorDona viejo) => true;
}
