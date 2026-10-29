import 'dart:convert';

import 'package:finanzas_hogar/actualizar.dart';
import 'package:finanzas_hogar/copia.dart';
import 'package:finanzas_hogar/datos.dart';
import 'package:finanzas_hogar/formato.dart';
import 'package:finanzas_hogar/pantallas/login.dart';
import 'package:finanzas_hogar/modelo.dart';
import 'package:flutter/material.dart';
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

  test('plan del mes: previsto frente a real', () {
    final mes = DateTime(2026, 10);
    final planes = [
      Plan(id: '1', mes: mes, tipo: TipoMovimiento.gasto, categoria: 'renta', monto: 750, nota: ''),
      Plan(id: '2', mes: mes, tipo: TipoMovimiento.gasto, categoria: 'comida', monto: 300, nota: ''),
      Plan(id: '3', mes: mes, tipo: TipoMovimiento.gasto, categoria: 'comida', monto: 100, nota: 'Fiesta'),
      Plan(id: '4', mes: mes, tipo: TipoMovimiento.ingreso, categoria: 'salario', monto: 2000, nota: ''),
      Plan(id: '5', mes: mes, tipo: TipoMovimiento.ahorro, categoria: 'guardar', monto: 200, nota: ''),
      Plan(id: '6', mes: DateTime(2026, 9), tipo: TipoMovimiento.gasto, categoria: 'renta', monto: 999, nota: ''),
    ];
    final movs = [
      mov('a', TipoMovimiento.gasto, 'comida', 450, DateTime(2026, 10, 3)),
      mov('a', TipoMovimiento.gasto, 'ocio', 30, DateTime(2026, 10, 4)),
      mov('a', TipoMovimiento.ahorro, 'guardar', 250, DateTime(2026, 10, 5)),
      mov('a', TipoMovimiento.ahorro, 'retirar', -50, DateTime(2026, 10, 6)),
    ];
    final r = ResumenPlan.calcular(planes, movs, mes);
    expect(r.previsto(TipoMovimiento.gasto), 1150);
    expect(r.real(TipoMovimiento.gasto), 480);
    expect(r.librePrevisto, 650);
    final comida = r.lineas[TipoMovimiento.gasto]!.firstWhere((l) => l.categoria == 'comida');
    expect(comida.previsto, 400);
    expect(comida.diferencia, 50);
    final ocio = r.lineas[TipoMovimiento.gasto]!.firstWhere((l) => l.categoria == 'ocio');
    expect(ocio.previsto, 0);
    expect(r.real(TipoMovimiento.ahorro), 200);
  });

  test('saldo y próximo pago de una tarjeta', () {
    const visa = Deuda(
      id: 'v',
      usuarioId: 'a',
      nombre: 'Visa',
      tipo: TipoDeuda.tarjeta,
      limite: 1000,
      saldoInicial: 300,
      diaPago: 31,
    );
    final movs = [
      Movimiento(
        id: '1',
        usuarioId: 'a',
        tipo: TipoMovimiento.gasto,
        categoria: 'comida',
        monto: 80,
        nota: '',
        fecha: DateTime(2026, 10, 1),
        deudaId: 'v',
      ),
      Movimiento(
        id: '2',
        usuarioId: 'a',
        tipo: TipoMovimiento.gasto,
        categoria: 'comida',
        monto: 40,
        nota: '',
        fecha: DateTime(2026, 10, 1),
      ),
    ];
    final ops = [
      OperacionDeuda(
        id: 'p',
        deudaId: 'v',
        usuarioId: 'a',
        esPago: true,
        monto: 100,
        nota: '',
        fecha: DateTime(2026, 10, 2),
      ),
      OperacionDeuda(
        id: 'c',
        deudaId: 'v',
        usuarioId: 'a',
        esPago: false,
        monto: 5,
        nota: '',
        fecha: DateTime(2026, 10, 2),
      ),
      OperacionDeuda(
        id: 'x',
        deudaId: 'otra',
        usuarioId: 'a',
        esPago: true,
        monto: 999,
        nota: '',
        fecha: DateTime(2026, 10, 2),
      ),
    ];
    expect(visa.saldo(movs, ops), 285);
    expect(visa.proximoPago(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
    expect(visa.proximoPago(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
    expect(visa.proximoPago(DateTime(2026, 11, 1)), DateTime(2026, 11, 30));
  });

  test('al anotar desde otro mes, la fecha empieza en ese mes', () {
    final hoy = DateTime(2026, 10, 29);
    expect(fechaInicialPara(DateTime(2026, 11), hoy), DateTime(2026, 11, 1));
    expect(fechaInicialPara(DateTime(2026, 9), hoy), DateTime(2026, 9, 1));
    expect(fechaInicialPara(DateTime(2026, 10), hoy), hoy);
    expect(fechaInicialPara(null, hoy), hoy);
  });

  test('número de versión desde la etiqueta de GitHub', () {
    expect(numeroDeEtiqueta('v12'), 12);
    expect(numeroDeEtiqueta('7'), 7);
    expect(numeroDeEtiqueta('latest'), null);
  });

  test('copia de seguridad: se exporta y se vuelve a leer', () {
    final d = DatosHogar()
      ..hogar = const Hogar(id: 'h', nombre: 'Casa', codigo: 'ABC123', moneda: 'MXN')
      ..miembros = const [Miembro(usuarioId: 'a', nombre: 'Ale', color: Color(0xFF000000))]
      ..movimientos = [
        Movimiento(
          id: 'm',
          usuarioId: 'a',
          tipo: TipoMovimiento.ingreso,
          categoria: 'salario',
          monto: 1500.5,
          nota: 'TUI',
          fecha: DateTime(2026, 11, 1),
        ),
      ]
      ..deudas = const [
        Deuda(
          id: 'd',
          usuarioId: 'a',
          nombre: 'Visa',
          tipo: TipoDeuda.tarjeta,
          limite: null,
          saldoInicial: 10,
          diaPago: 5,
        ),
      ];
    final bytes = utf8.encode(jsonEncode(copiaDelHogar(d, DateTime(2026, 11, 2))));
    final leida = leerCopia(bytes);
    expect(leida['hogar']['moneda'], 'MXN');
    expect(leida['movimientos'][0]['fecha'], '2026-11-01');
    expect(leida['movimientos'][0]['monto'], 1500.5);
    expect(leida['deudas'][0]['tipo'], 'tarjeta');
    expect(() => leerCopia(utf8.encode('{"app": "otra"}')), throwsFormatException);
    expect(() => leerCopia(utf8.encode('no es json')), throwsFormatException);
  });

  testWidgets('la pantalla de entrada se muestra', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaLogin()));
    expect(find.text('Finanzas del Hogar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsWidgets);
  });
}
