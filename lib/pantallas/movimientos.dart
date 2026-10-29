import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import 'editar_movimiento.dart';
import 'resumen.dart';

class PestanaMovimientos extends StatefulWidget {
  final DatosHogar datos;
  final DateTime mes;

  const PestanaMovimientos({super.key, required this.datos, required this.mes});

  @override
  State<PestanaMovimientos> createState() => _PestanaMovimientosState();
}

class _PestanaMovimientosState extends State<PestanaMovimientos> {
  /// null = todos; si no, el id de la persona.
  String? _persona;
  TipoMovimiento? _tipo;

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    final moneda = datos.hogar!.moneda;
    final lista = datos.movimientos
        .where((m) => m.esDelMes(widget.mes))
        .where((m) => _persona == null || m.usuarioId == _persona)
        .where((m) => _tipo == null || m.tipo == _tipo)
        .toList();

    final grupos = <DateTime, List<Movimiento>>{};
    for (final m in lista) {
      grupos.putIfAbsent(DateTime(m.fecha.year, m.fecha.month, m.fecha.day), () => []).add(m);
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _Filtro('Todos', _persona == null, () => setState(() => _persona = null)),
              for (final m in datos.miembros)
                _Filtro(
                  m.usuarioId == miUsuarioId ? 'Yo' : m.nombre,
                  _persona == m.usuarioId,
                  () => setState(() => _persona = m.usuarioId),
                  color: m.color,
                ),
              const SizedBox(width: 8),
              const SizedBox(height: 24, child: VerticalDivider()),
              for (final t in TipoMovimiento.values)
                _Filtro(_nombreTipo(t), _tipo == t, () => setState(() => _tipo = _tipo == t ? null : t)),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Text(
                        'No hay movimientos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final dia in grupos.keys) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(fechaDia(dia), style: Theme.of(context).textTheme.labelLarge)),
                            Text(
                              dinero(_netoDelDia(grupos[dia]!), moneda),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      for (final m in grupos[dia]!) _FilaMovimiento(m: m, datos: datos),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  double _netoDelDia(List<Movimiento> lista) => lista.fold(0, (s, m) {
    return switch (m.tipo) {
      TipoMovimiento.ingreso => s + m.monto,
      TipoMovimiento.gasto => s - m.monto,
      TipoMovimiento.ahorro => s - m.monto,
    };
  });
}

String _nombreTipo(TipoMovimiento t) => switch (t) {
  TipoMovimiento.gasto => 'Gastos',
  TipoMovimiento.ingreso => 'Ingresos',
  TipoMovimiento.ahorro => 'Ahorro',
};

class _Filtro extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback alPulsar;
  final Color? color;

  const _Filtro(this.texto, this.activo, this.alPulsar, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(texto),
        selected: activo,
        onSelected: (_) => alPulsar(),
        avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 6),
        showCheckmark: false,
      ),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  final Movimiento m;
  final DatosHogar datos;

  const _FilaMovimiento({required this.m, required this.datos});

  @override
  Widget build(BuildContext context) {
    final cat = categoriaPorClave(m.categoria);
    final persona = datos.miembro(m.usuarioId);
    final esMio = m.usuarioId == miUsuarioId;
    final moneda = datos.hogar!.moneda;
    final (signo, color) = switch (m.tipo) {
      TipoMovimiento.ingreso => ('+', verdeIngreso),
      TipoMovimiento.gasto => ('−', rojoGasto),
      TipoMovimiento.ahorro => (m.monto >= 0 ? '→ ' : '← ', azulAhorro),
    };

    final fila = ListTile(
      leading: CircleAvatar(backgroundColor: cat.color, foregroundColor: Colors.white, child: Icon(cat.icono)),
      title: Text(m.nota.isEmpty ? cat.nombre : m.nota, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (m.nota.isNotEmpty) Flexible(child: Text('${cat.nombre} · ', overflow: TextOverflow.ellipsis)),
          CircleAvatar(radius: 5, backgroundColor: persona.color),
          const SizedBox(width: 4),
          Flexible(child: Text(esMio ? 'Yo' : persona.nombre, overflow: TextOverflow.ellipsis)),
          if (datos.deuda(m.deudaId) case final tarjeta?) ...[
            const SizedBox(width: 6),
            const Icon(Icons.credit_card, size: 14),
            const SizedBox(width: 2),
            Flexible(child: Text(tarjeta.nombre, overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
      trailing: Text(
        '$signo${dinero(m.monto.abs(), moneda)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      onTap: esMio
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PantallaEditarMovimiento(datos: datos, movimiento: m),
                fullscreenDialog: true,
              ),
            )
          : () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Solo ${persona.nombre} puede cambiar este movimiento.'))),
    );

    if (!esMio) return fila;
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (_) => confirmarBorrado(context),
      onDismissed: (_) async {
        final mensajero = ScaffoldMessenger.of(context);
        try {
          await datos.borrarMovimiento(m.id);
        } catch (e) {
          mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
        }
      },
      child: fila,
    );
  }
}

Future<bool> confirmarBorrado(BuildContext context) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar este movimiento?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
      ],
    ),
  );
  return si ?? false;
}
