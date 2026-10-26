import 'package:flutter/material.dart';

enum TipoMovimiento { ingreso, gasto, ahorro }

TipoMovimiento tipoDesdeTexto(String texto) =>
    TipoMovimiento.values.firstWhere((t) => t.name == texto, orElse: () => TipoMovimiento.gasto);

class Categoria {
  final String clave;
  final String nombre;
  final IconData icono;
  final Color color;

  const Categoria(this.clave, this.nombre, this.icono, this.color);
}

const categoriasGasto = <Categoria>[
  Categoria('comida', 'Comida y súper', Icons.shopping_cart, Color(0xFF43A047)),
  Categoria('renta', 'Renta / Vivienda', Icons.home, Color(0xFF5E35B1)),
  Categoria('servicios', 'Luz, agua, internet', Icons.bolt, Color(0xFFFFB300)),
  Categoria('transporte', 'Transporte', Icons.directions_car, Color(0xFF1E88E5)),
  Categoria('salud', 'Salud', Icons.local_hospital, Color(0xFFE53935)),
  Categoria('hijos', 'Hijos', Icons.child_care, Color(0xFFEC407A)),
  Categoria('educacion', 'Educación', Icons.school, Color(0xFF3949AB)),
  Categoria('ropa', 'Ropa', Icons.checkroom, Color(0xFF8E24AA)),
  Categoria('restaurantes', 'Restaurantes', Icons.restaurant, Color(0xFFF4511E)),
  Categoria('ocio', 'Ocio', Icons.celebration, Color(0xFF00ACC1)),
  Categoria('hogar', 'Cosas de casa', Icons.chair, Color(0xFF6D4C41)),
  Categoria('mascotas', 'Mascotas', Icons.pets, Color(0xFF7CB342)),
  Categoria('regalos', 'Regalos', Icons.card_giftcard, Color(0xFFD81B60)),
  Categoria('deudas', 'Deudas / Préstamos', Icons.account_balance, Color(0xFF546E7A)),
  Categoria('otros_gasto', 'Otros', Icons.more_horiz, Color(0xFF757575)),
];

const categoriasIngreso = <Categoria>[
  Categoria('salario', 'Salario', Icons.work, Color(0xFF2E7D32)),
  Categoria('negocio', 'Negocio / Extra', Icons.storefront, Color(0xFF00897B)),
  Categoria('regalo_ingreso', 'Regalo / Ayuda', Icons.volunteer_activism, Color(0xFFC2185B)),
  Categoria('reembolso', 'Reembolso', Icons.replay, Color(0xFF0277BD)),
  Categoria('otros_ingreso', 'Otros', Icons.more_horiz, Color(0xFF757575)),
];

const categoriasAhorro = <Categoria>[
  Categoria('guardar', 'Guardar', Icons.savings, Color(0xFF00897B)),
  Categoria('retirar', 'Sacar del ahorro', Icons.outbox, Color(0xFFEF6C00)),
];

List<Categoria> categoriasDe(TipoMovimiento tipo) => switch (tipo) {
      TipoMovimiento.gasto => categoriasGasto,
      TipoMovimiento.ingreso => categoriasIngreso,
      TipoMovimiento.ahorro => categoriasAhorro,
    };

Categoria categoriaPorClave(String clave) {
  for (final c in [...categoriasGasto, ...categoriasIngreso, ...categoriasAhorro]) {
    if (c.clave == clave) return c;
  }
  return const Categoria('otros', 'Otros', Icons.more_horiz, Color(0xFF757575));
}

class Hogar {
  final String id;
  final String nombre;
  final String codigo;
  final String moneda;

  const Hogar({required this.id, required this.nombre, required this.codigo, required this.moneda});

  factory Hogar.desdeMapa(Map<String, dynamic> m) => Hogar(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        codigo: m['codigo'] as String,
        moneda: m['moneda'] as String,
      );
}

const coloresPersona = <Color>[
  Color(0xFF1E88E5),
  Color(0xFFD81B60),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

class Miembro {
  final String usuarioId;
  final String nombre;
  final Color color;

  const Miembro({required this.usuarioId, required this.nombre, required this.color});
}

class Movimiento {
  final String id;
  final String usuarioId;
  final TipoMovimiento tipo;
  final String categoria;

  /// En el ahorro, un monto negativo es dinero que se saca del ahorro.
  final double monto;
  final String nota;
  final DateTime fecha;

  const Movimiento({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.categoria,
    required this.monto,
    required this.nota,
    required this.fecha,
  });

  factory Movimiento.desdeMapa(Map<String, dynamic> m) => Movimiento(
        id: m['id'] as String,
        usuarioId: m['usuario_id'] as String,
        tipo: tipoDesdeTexto(m['tipo'] as String),
        categoria: m['categoria'] as String,
        monto: (m['monto'] as num).toDouble(),
        nota: (m['nota'] as String?) ?? '',
        fecha: DateTime.parse(m['fecha'] as String),
      );

  bool esDelMes(DateTime mes) => fecha.year == mes.year && fecha.month == mes.month;
}

class ResumenPersona {
  double ingresos = 0;
  double gastos = 0;
  double ahorro = 0;
}

/// Totales de un mes, más el ahorro acumulado de todos los meses hasta ese.
class Resumen {
  final double ingresos;
  final double gastos;
  final double ahorroMes;
  final double ahorroAcumulado;
  final Map<String, double> gastosPorCategoria;
  final Map<String, ResumenPersona> porPersona;

  const Resumen({
    required this.ingresos,
    required this.gastos,
    required this.ahorroMes,
    required this.ahorroAcumulado,
    required this.gastosPorCategoria,
    required this.porPersona,
  });

  /// Lo que queda libre este mes después de gastar y apartar al ahorro.
  double get disponible => ingresos - gastos - ahorroMes;

  factory Resumen.calcular(Iterable<Movimiento> movimientos, DateTime mes) {
    double ingresos = 0, gastos = 0, ahorroMes = 0, ahorroAcumulado = 0;
    final porCategoria = <String, double>{};
    final porPersona = <String, ResumenPersona>{};
    final finDeMes = DateTime(mes.year, mes.month + 1);

    for (final m in movimientos) {
      if (m.tipo == TipoMovimiento.ahorro && m.fecha.isBefore(finDeMes)) {
        ahorroAcumulado += m.monto;
      }
      if (!m.esDelMes(mes)) continue;
      final persona = porPersona.putIfAbsent(m.usuarioId, ResumenPersona.new);
      switch (m.tipo) {
        case TipoMovimiento.ingreso:
          ingresos += m.monto;
          persona.ingresos += m.monto;
        case TipoMovimiento.gasto:
          gastos += m.monto;
          persona.gastos += m.monto;
          porCategoria[m.categoria] = (porCategoria[m.categoria] ?? 0) + m.monto;
        case TipoMovimiento.ahorro:
          ahorroMes += m.monto;
          persona.ahorro += m.monto;
      }
    }

    final ordenadas = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Resumen(
      ingresos: ingresos,
      gastos: gastos,
      ahorroMes: ahorroMes,
      ahorroAcumulado: ahorroAcumulado,
      gastosPorCategoria: Map.fromEntries(ordenadas),
      porPersona: porPersona,
    );
  }
}
