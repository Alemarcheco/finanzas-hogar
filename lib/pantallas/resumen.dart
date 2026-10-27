import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import '../widgets/grafico_dona.dart';

const verdeIngreso = Color(0xFF2E7D32);
const rojoGasto = Color(0xFFC62828);
const azulAhorro = Color(0xFF00838F);

class PestanaResumen extends StatelessWidget {
  final DatosHogar datos;
  final DateTime mes;
  final ValueChanged<int> irA;

  const PestanaResumen({super.key, required this.datos, required this.mes, required this.irA});

  @override
  Widget build(BuildContext context) {
    final moneda = datos.hogar!.moneda;
    final r = Resumen.calcular(datos.movimientos, mes);
    final anterior = Resumen.calcular(datos.movimientos, DateTime(mes.year, mes.month - 1));
    final hayDatos = r.ingresos != 0 || r.gastos != 0 || r.ahorroMes != 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (datos.error != null) _AvisoError(datos.error!),
        _TarjetaBalance(r: r, anterior: anterior, moneda: moneda),
        const SizedBox(height: 12),
        _TarjetaAhorro(r: r, moneda: moneda),
        const SizedBox(height: 12),
        _TarjetaPlanYDeudas(datos: datos, mes: mes, irA: irA),
        const SizedBox(height: 12),
        if (!hayDatos)
          const _Vacio()
        else ...[
          if (r.gastos > 0) _TarjetaCategorias(r: r, moneda: moneda),
          const SizedBox(height: 12),
          _TarjetaPersonas(r: r, datos: datos, moneda: moneda),
        ],
      ],
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String texto;

  const _AvisoError(this.texto);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.errorContainer,
      child: ListTile(
        leading: Icon(Icons.cloud_off, color: c.onErrorContainer),
        title: Text('Sin conexión con el servidor', style: TextStyle(color: c.onErrorContainer)),
        subtitle: Text(texto, style: TextStyle(color: c.onErrorContainer)),
      ),
    );
  }
}

class _TarjetaBalance extends StatelessWidget {
  final Resumen r;
  final Resumen anterior;
  final String moneda;

  const _TarjetaBalance({required this.r, required this.anterior, required this.moneda});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    String? comparacion;
    if (anterior.gastos > 0 && r.gastos > 0) {
      final cambio = (r.gastos - anterior.gastos) / anterior.gastos * 100;
      comparacion = cambio >= 0
          ? 'Gastos: ${cambio.toStringAsFixed(0)}% más que el mes anterior'
          : 'Gastos: ${(-cambio).toStringAsFixed(0)}% menos que el mes anterior';
    }
    return Card(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Queda libre este mes', style: t.titleSmall?.copyWith(color: c.onPrimaryContainer)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                dinero(r.disponible, moneda),
                style: t.displaySmall?.copyWith(
                  color: r.disponible < 0 ? rojoGasto : c.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Cifra('Ingresos', r.ingresos, moneda, verdeIngreso, Icons.arrow_downward),
                _Cifra('Gastos', r.gastos, moneda, rojoGasto, Icons.arrow_upward),
                _Cifra('Ahorrado', r.ahorroMes, moneda, azulAhorro, Icons.savings),
              ],
            ),
            if (comparacion != null) ...[
              const SizedBox(height: 12),
              Text(comparacion, style: t.bodySmall?.copyWith(color: c.onPrimaryContainer)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  final String titulo;
  final double valor;
  final String moneda;
  final Color color;
  final IconData icono;

  const _Cifra(this.titulo, this.valor, this.moneda, this.color, this.icono);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 4),
              Text(titulo, style: TextStyle(fontSize: 12, color: c.onPrimaryContainer)),
            ],
          ),
          FittedBox(
            child: Text(
              dinero(valor, moneda),
              style: TextStyle(fontWeight: FontWeight.w600, color: c.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAhorro extends StatelessWidget {
  final Resumen r;
  final String moneda;

  const _TarjetaAhorro({required this.r, required this.moneda});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: azulAhorro,
          foregroundColor: Colors.white,
          child: Icon(Icons.savings),
        ),
        title: const Text('Ahorro guardado'),
        subtitle: const Text('Todo lo apartado hasta este mes'),
        trailing: Text(
          dinero(r.ahorroAcumulado, moneda),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: azulAhorro),
        ),
      ),
    );
  }
}

class _TarjetaCategorias extends StatelessWidget {
  final Resumen r;
  final String moneda;

  const _TarjetaCategorias({required this.r, required this.moneda});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final entradas = r.gastosPorCategoria.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿En qué se fue el dinero?', style: t.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: GraficoDona(
                porciones: [for (final e in entradas) PorcionDona(e.value, categoriaPorClave(e.key).color)],
                centro: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gastos', style: t.bodySmall),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: FittedBox(
                        child: Text(
                          dinero(r.gastos, moneda),
                          style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final e in entradas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: categoriaPorClave(e.key).color,
                      foregroundColor: Colors.white,
                      child: Icon(categoriaPorClave(e.key).icono, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(categoriaPorClave(e.key).nombre)),
                              Text(dinero(e.value, moneda), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: e.value / r.gastos,
                                    minHeight: 6,
                                    color: categoriaPorClave(e.key).color,
                                    backgroundColor: c.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${(e.value / r.gastos * 100).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right,
                                  style: t.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPersonas extends StatelessWidget {
  final Resumen r;
  final DatosHogar datos;
  final String moneda;

  const _TarjetaPersonas({required this.r, required this.datos, required this.moneda});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    // Primero los miembros actuales, luego quien ya no esté pero anotó algo.
    final ids = [
      for (final m in datos.miembros) m.usuarioId,
      for (final id in r.porPersona.keys)
        if (!datos.miembros.any((m) => m.usuarioId == id)) id,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Quién gastó qué?', style: t.titleMedium),
            const SizedBox(height: 12),
            for (final id in ids) ...[
              Builder(
                builder: (context) {
                  final m = datos.miembro(id);
                  final p = r.porPersona[id] ?? ResumenPersona();
                  final parte = r.gastos > 0 ? p.gastos / r.gastos : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: m.color,
                              foregroundColor: Colors.white,
                              child: Text(
                                m.nombre.isEmpty ? '?' : m.nombre[0].toUpperCase(),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                id == miUsuarioId ? '${m.nombre} (tú)' : m.nombre,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text('${(parte * 100).toStringAsFixed(0)}% del gasto', style: t.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: parte,
                            minHeight: 8,
                            color: m.color,
                            backgroundColor: c.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          children: [
                            Text('Gastó ${dinero(p.gastos, moneda)}', style: t.bodySmall?.copyWith(color: rojoGasto)),
                            Text(
                              'Ingresó ${dinero(p.ingresos, moneda)}',
                              style: t.bodySmall?.copyWith(color: verdeIngreso),
                            ),
                            if (p.ahorro != 0)
                              Text(
                                'Ahorró ${dinero(p.ahorro, moneda)}',
                                style: t.bodySmall?.copyWith(color: azulAhorro),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 64, color: c.outline),
          const SizedBox(height: 12),
          Text(
            'Aún no hay nada anotado este mes.\nPulsa "Anotar" para añadir un gasto o un ingreso.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Avance del plan del mes y total de deudas, con acceso a sus pestañas.
class _TarjetaPlanYDeudas extends StatelessWidget {
  final DatosHogar datos;
  final DateTime mes;
  final ValueChanged<int> irA;

  const _TarjetaPlanYDeudas({required this.datos, required this.mes, required this.irA});

  @override
  Widget build(BuildContext context) {
    final moneda = datos.hogar!.moneda;
    final c = Theme.of(context).colorScheme;
    final plan = ResumenPlan.calcular(datos.planes, datos.movimientos, mes);
    final previsto = plan.previsto(TipoMovimiento.gasto);
    final real = plan.real(TipoMovimiento.gasto);
    final deuda = datos.deudas.fold<double>(0, (s, d) => s + datos.saldoDeuda(d));
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_note),
            title: const Text('Plan del mes'),
            subtitle: previsto > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gastado ${dinero(real, moneda)} de ${dinero(previsto, moneda)} previstos'),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (real / previsto).clamp(0, 1).toDouble(),
                          minHeight: 6,
                          color: real > previsto ? rojoGasto : c.primary,
                          backgroundColor: c.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  )
                : const Text('Aún no hay gastos previstos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => irA(2),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Tarjetas y deudas'),
            subtitle: Text(datos.deudas.isEmpty ? 'Sin deudas anotadas' : 'Se debe ${dinero(deuda, moneda)} en total'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => irA(3),
          ),
        ],
      ),
    );
  }
}
