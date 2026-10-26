import 'package:finanzas_hogar/formato.dart';
import 'package:finanzas_hogar/main.dart';
import 'package:finanzas_hogar/modelo.dart';
import 'package:flutter_test/flutter_test.dart';

Movimiento mov(String usuario, TipoMovimiento tipo, String categoria, double monto, DateTime fecha) => Movimiento(
      id: '${fecha.toIso8601String()}-$monto',
      usuarioId: usuario,
      tipo: tipo,
      categoria: categoria,
      monto: monto,
      nota: '',
      fecha: fecha,
    );

void main() {
  test('resumen del mes por categoría y por persona', () {
    final lista = [
      mov('ana', TipoMovimiento.ingreso, 'salario', 1000, DateTime(2026, 10, 1)),
      mov('luis', TipoMovimiento.ingreso, 'salario', 800, DateTime(2026, 10, 2)),
      mov('ana', TipoMovimiento.gasto, 'comida', 150, DateTime(2026, 10, 3)),
      mov('luis', TipoMovimiento.gasto, 'comida', 50, DateTime(2026, 10, 4)),
      mov('luis', TipoMovimiento.gasto, 'renta', 600, DateTime(2026, 10, 5)),
      mov('ana', TipoMovimiento.ahorro, 'guardar', 300, DateTime(2026, 10, 6)),
      mov('ana', TipoMovimiento.ahorro, 'guardar', 200, DateTime(2026, 9, 6)),
      mov('ana', TipoMovimiento.ahorro, 'retirar', -50, DateTime(2026, 9, 20)),
      mov('ana', TipoMovimiento.gasto, 'ocio', 999, DateTime(2026, 9, 7)),
      mov('ana', TipoMovimiento.ahorro, 'guardar', 1000, DateTime(2026, 11, 1)),
    ];
    final r = Resumen.calcular(lista, DateTime(2026, 10));
    expect(r.ingresos, 1800);
    expect(r.gastos, 800);
    expect(r.ahorroMes, 300);
    expect(r.disponible, 700);
    expect(r.ahorroAcumulado, 450);
    expect(r.gastosPorCategoria.keys.first, 'renta');
    expect(r.gastosPorCategoria['comida'], 200);
    expect(r.porPersona['luis']!.gastos, 650);
    expect(r.porPersona['ana']!.ingresos, 1000);
  });

  test('leer cantidades escritas de distintas formas', () {
    expect(leerMonto('12,50'), 12.5);
    expect(leerMonto('12.50'), 12.5);
    expect(leerMonto('1.234,56'), 1234.56);
    expect(leerMonto('1,234.56'), 1234.56);
    expect(leerMonto(''), null);
    expect(leerMonto('abc'), null);
  });

  testWidgets('sin servidor configurado avisa en vez de fallar', (tester) async {
    await tester.pumpWidget(const FinanzasHogarApp());
    expect(find.textContaining('Supabase'), findsOneWidget);
  });
}
