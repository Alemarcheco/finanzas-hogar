import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import '../widgets/pedir_cuenta.dart';
import 'editar_movimiento.dart';
import 'resumen.dart';

Future<void> abrirEditorDeuda(BuildContext context, DatosHogar datos, {Deuda? deuda}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PantallaEditarDeuda(datos: datos, deuda: deuda),
      fullscreenDialog: true,
    ),
  );
}

String? textoProximoPago(Deuda d) {
  final hoy = DateTime.now();
  final fecha = d.proximoPago(hoy);
  if (fecha == null) return null;
  final dias = fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (dias == 0) return 'Se paga hoy';
  if (dias == 1) return 'Se paga mañana';
  return 'Se paga el día ${fecha.day} (en $dias días)';
}

/// Tarjetas de crédito, préstamos y otras deudas, agrupadas por persona.
class PestanaDeudas extends StatelessWidget {
  final DatosHogar datos;

  const PestanaDeudas({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    final moneda = datos.hogar!.moneda;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    if (datos.deudas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
        children: [
          Icon(Icons.credit_card, size: 64, color: c.outline),
          const SizedBox(height: 12),
          Text('Sin tarjetas ni deudas', textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Añade las tarjetas de crédito, préstamos u otras deudas de cada uno, con lo que se debe ahora. '
            'Después, al anotar un gasto podrás decir con qué tarjeta se pagó, y aquí anotarás los pagos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir tarjeta o deuda'),
            onPressed: () => abrirEditorDeuda(context, datos),
          ),
        ],
      );
    }

    final total = datos.deudas.fold<double>(0, (s, d) => s + datos.saldoDeuda(d));
    final ids = <String>{
      for (final m in datos.miembros) m.usuarioId,
      for (final d in datos.deudas) d.usuarioId,
    }.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          color: c.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lo que se debe en total', style: t.titleSmall?.copyWith(color: c.onErrorContainer)),
                FittedBox(
                  child: Text(
                    dinero(total, moneda),
                    style: t.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: c.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final id in ids)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 5, backgroundColor: datos.miembro(id).color),
                          const SizedBox(width: 4),
                          Text(
                            '${datos.miembro(id).nombre}: ${dinero(datos.deudas.where((d) => d.usuarioId == id).fold(0.0, (s, d) => s + datos.saldoDeuda(d)), moneda)}',
                            style: TextStyle(color: c.onErrorContainer),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final id in ids)
          if (datos.deudas.any((d) => d.usuarioId == id)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: datos.miembro(id).color,
                    foregroundColor: Colors.white,
                    child: Text(
                      datos.miembro(id).nombre.isEmpty ? '?' : datos.miembro(id).nombre[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    id == miUsuarioId ? 'Lo que debo yo' : 'Lo que debe ${datos.miembro(id).nombre}',
                    style: t.titleMedium,
                  ),
                ],
              ),
            ),
            for (final d in datos.deudas.where((d) => d.usuarioId == id)) _TarjetaDeuda(deuda: d, datos: datos),
          ],
      ],
    );
  }
}

class _TarjetaDeuda extends StatelessWidget {
  final Deuda deuda;
  final DatosHogar datos;

  const _TarjetaDeuda({required this.deuda, required this.datos});

  @override
  Widget build(BuildContext context) {
    final moneda = datos.hogar!.moneda;
    final saldo = datos.saldoDeuda(deuda);
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final limite = deuda.limite;
    final pago = textoProximoPago(deuda);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListenableBuilder(
              listenable: datos,
              builder: (_, _) => PantallaDetalleDeuda(datos: datos, deudaId: deuda.id),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconosTipoDeuda[deuda.tipo], color: datos.miembro(deuda.usuarioId).color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deuda.nombre, style: t.titleMedium),
                        Text(pago ?? nombresTipoDeuda[deuda.tipo]!, style: t.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    dinero(saldo, moneda),
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: saldo > 0 ? rojoGasto : verdeIngreso,
                    ),
                  ),
                ],
              ),
              if (limite != null && limite > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (saldo / limite).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: saldo / limite > 0.8 ? rojoGasto : c.primary,
                    backgroundColor: c.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Disponible ${dinero(limite - saldo, moneda)} de ${dinero(limite, moneda)}', style: t.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Saldo, próximos pagos e historial de una tarjeta o deuda.
class PantallaDetalleDeuda extends StatelessWidget {
  final DatosHogar datos;
  final String deudaId;

  const PantallaDetalleDeuda({super.key, required this.datos, required this.deudaId});

  @override
  Widget build(BuildContext context) {
    final deuda = datos.deuda(deudaId);
    if (deuda == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Esta deuda se ha borrado.')),
      );
    }
    final moneda = datos.hogar!.moneda;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final saldo = datos.saldoDeuda(deuda);
    final pago = textoProximoPago(deuda);

    // Historial: pagos, cargos y gastos pagados con esta tarjeta.
    final historial =
        <({DateTime fecha, String titulo, String clase, String quien, double monto, VoidCallback? alPulsar})>[
          for (final o in datos.operacionesDeuda.where((o) => o.deudaId == deuda.id))
            (
              fecha: o.fecha,
              titulo: o.nota.isNotEmpty ? o.nota : (o.esPago ? 'Pago' : 'Cargo'),
              clase: o.esPago ? (o.cuenta == null ? 'Pago' : 'Pago desde ${o.cuenta}') : 'Cargo',
              quien: datos.miembro(o.usuarioId).nombre,
              monto: o.esPago ? -o.monto : o.monto,
              alPulsar: () => _opcionesOperacion(context, o),
            ),
          for (final m in datos.movimientos.where((m) => m.deudaId == deuda.id && m.tipo == TipoMovimiento.gasto))
            (
              fecha: m.fecha,
              titulo: m.nota.isNotEmpty ? m.nota : categoriaPorClave(m.categoria).nombre,
              clase: 'Compra',
              quien: datos.miembro(m.usuarioId).nombre,
              monto: m.monto,
              alPulsar: m.usuarioId == miUsuarioId
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PantallaEditarMovimiento(datos: datos, movimiento: m),
                        fullscreenDialog: true,
                      ),
                    )
                  : null,
            ),
        ]..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      appBar: AppBar(
        title: Text(deuda.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => abrirEditorDeuda(context, datos, deuda: deuda),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: datos.refrescar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: c.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${nombresTipoDeuda[deuda.tipo]} de ${datos.miembro(deuda.usuarioId).nombre}',
                      style: t.titleSmall?.copyWith(color: c.onErrorContainer),
                    ),
                    FittedBox(
                      child: Text(
                        dinero(saldo, moneda),
                        style: t.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: c.onErrorContainer),
                      ),
                    ),
                    if (deuda.limite != null)
                      Text(
                        'Límite ${dinero(deuda.limite!, moneda)} · disponible ${dinero(deuda.limite! - saldo, moneda)}',
                        style: TextStyle(color: c.onErrorContainer),
                      ),
                    if (pago != null) Text(pago, style: TextStyle(color: c.onErrorContainer)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.payments),
                    label: const Text('Anotar pago'),
                    onPressed: () => _anotar(context, deuda, esPago: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_card),
                    label: const Text('Sumar a la deuda'),
                    onPressed: () => _anotar(context, deuda, esPago: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              deuda.tipo == TipoDeuda.tarjeta
                  ? '"Anotar pago" baja lo que se debe. Las compras se suman solas si al anotar el gasto eliges '
                        'esta tarjeta; "Sumar a la deuda" es para intereses o comisiones.'
                  : '"Anotar pago" baja lo que se debe. "Sumar a la deuda" es para intereses o si te prestan más.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text('Historial', style: t.titleMedium),
            if (historial.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay pagos ni compras.')),
            for (final h in historial)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  h.monto < 0 ? Icons.south_west : Icons.north_east,
                  color: h.monto < 0 ? verdeIngreso : rojoGasto,
                ),
                title: Text(h.titulo),
                subtitle: Text('${h.clase} · ${fechaDia(h.fecha)} · ${h.quien}'),
                trailing: Text(
                  '${h.monto < 0 ? '−' : '+'}${dinero(h.monto.abs(), moneda)}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: h.monto < 0 ? verdeIngreso : rojoGasto),
                ),
                onTap: h.alPulsar,
              ),
            if (deuda.saldoInicial != 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag),
                title: const Text('Lo que se debía al empezar'),
                trailing: Text(dinero(deuda.saldoInicial, moneda), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _opcionesOperacion(BuildContext context, OperacionDeuda o) async {
    final mensajero = ScaffoldMessenger.of(context);
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(o.esPago ? Icons.north_east : Icons.south_west),
              title: Text(o.esPago ? 'Cambiar a "Sumar a la deuda"' : 'Cambiar a pago'),
              subtitle: Text(o.esPago ? 'La deuda subirá en vez de bajar' : 'La deuda bajará en vez de subir'),
              onTap: () => Navigator.pop(hoja, 'cambiar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Borrar'),
              onTap: () => Navigator.pop(hoja, 'borrar'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (eleccion == 'borrar') return _borrarOperacion(context, o);
    if (eleccion == 'cambiar') {
      try {
        await datos.cambiarTipoOperacion(o);
      } catch (e) {
        mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  Future<void> _borrarOperacion(BuildContext context, OperacionDeuda o) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(o.esPago ? '¿Borrar este pago?' : '¿Borrar este cargo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (si != true || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await datos.borrarOperacionDeuda(o.id);
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _anotar(BuildContext context, Deuda deuda, {required bool esPago}) async {
    final saldoActual = datos.saldoDeuda(deuda);
    final moneda = datos.hogar!.moneda;
    final monto = TextEditingController();
    final nota = TextEditingController();
    var fecha = DateTime.now();
    // Los pagos de préstamos suelen ser un gasto del mes; el pago de la tarjeta no,
    // porque las compras ya se anotaron como gasto.
    var comoGasto = esPago && deuda.tipo != TipoDeuda.tarjeta;
    // De dónde sale el dinero del pago: efectivo (null), una cuenta de débito u otra tarjeta.
    String? cuenta;
    Deuda? desdeTarjeta;
    final cuentas = [...datos.cuentas];
    final otrasTarjetas = [
      for (final d in datos.deudas)
        if (d.tipo == TipoDeuda.tarjeta && d.id != deuda.id) d,
    ];
    final mensajero = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(deuda.nombre),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Pago'), icon: Icon(Icons.south_west)),
                    ButtonSegment(value: false, label: Text('Sumar'), icon: Icon(Icons.north_east)),
                  ],
                  selected: {esPago},
                  onSelectionChanged: (v) => setState(() {
                    esPago = v.first;
                    comoGasto = esPago && deuda.tipo != TipoDeuda.tarjeta;
                  }),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final cantidad = leerMonto(monto.text) ?? 0;
                    final queda = esPago ? saldoActual - cantidad : saldoActual + cantidad;
                    return Text(
                      '${esPago ? 'Baja' : 'Sube'} lo que se debe: '
                      '${dinero(saldoActual, moneda)} → ${dinero(queda, moneda)}',
                      style: TextStyle(color: esPago ? verdeIngreso : rojoGasto, fontWeight: FontWeight.w600),
                    );
                  },
                ),
                TextField(
                  controller: monto,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Cantidad', prefixText: '${datos.hogar!.moneda} '),
                ),
                TextField(
                  controller: nota,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(fechaDia(fecha)),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (f != null) setState(() => fecha = f);
                  },
                ),
                if (esPago) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('¿De dónde sale el dinero?', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.payments, size: 18),
                        label: const Text('Efectivo'),
                        selected: cuenta == null && desdeTarjeta == null,
                        onSelected: (_) => setState(() {
                          cuenta = null;
                          desdeTarjeta = null;
                        }),
                      ),
                      for (final c in cuentas)
                        ChoiceChip(
                          avatar: const Icon(Icons.account_balance, size: 18),
                          label: Text(c),
                          selected: cuenta == c,
                          onSelected: (_) => setState(() {
                            cuenta = c;
                            desdeTarjeta = null;
                          }),
                        ),
                      for (final t in otrasTarjetas)
                        ChoiceChip(
                          avatar: const Icon(Icons.credit_card, size: 18),
                          label: Text(t.nombre),
                          selected: desdeTarjeta?.id == t.id,
                          onSelected: (_) => setState(() {
                            desdeTarjeta = t;
                            cuenta = null;
                          }),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva cuenta de débito'),
                        onPressed: () async {
                          final nueva = await pedirNombreCuenta(context);
                          if (nueva != null) {
                            setState(() {
                              if (!cuentas.contains(nueva)) cuentas.add(nueva);
                              cuenta = nueva;
                              desdeTarjeta = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (cuenta != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Se descontará de $cuenta.', style: Theme.of(context).textTheme.bodySmall),
                    ),
                  if (desdeTarjeta != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Se sumará a lo que se debe de ${desdeTarjeta!.nombre}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                if (esPago)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: comoGasto,
                    onChanged: (v) => setState(() => comoGasto = v),
                    title: const Text('Contarlo también como gasto del mes'),
                    subtitle: Text(
                      deuda.tipo == TipoDeuda.tarjeta
                          ? 'Normalmente no: las compras con la tarjeta ya se anotaron como gasto.'
                          : 'Se anotará en "Deudas / Préstamos".',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final cantidad = leerMonto(monto.text);
    if (cantidad == null || cantidad <= 0) {
      mensajero.showSnackBar(const SnackBar(content: Text('Escribe una cantidad mayor que cero.')));
      return;
    }
    try {
      await datos.anotarOperacionDeuda(
        deuda: deuda,
        esPago: esPago,
        monto: cantidad,
        nota: nota.text.trim(),
        fecha: fecha,
        tambienComoGasto: comoGasto,
        cuenta: esPago ? cuenta : null,
        desdeTarjeta: esPago ? desdeTarjeta : null,
      );
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }
}

class PantallaEditarDeuda extends StatefulWidget {
  final DatosHogar datos;
  final Deuda? deuda;

  const PantallaEditarDeuda({super.key, required this.datos, this.deuda});

  @override
  State<PantallaEditarDeuda> createState() => _PantallaEditarDeudaState();
}

class _PantallaEditarDeudaState extends State<PantallaEditarDeuda> {
  late TipoDeuda _tipo;
  late String _usuarioId;
  int? _diaPago;
  final _nombre = TextEditingController();
  final _saldo = TextEditingController();
  final _limite = TextEditingController();
  bool _ocupado = false;

  String _numero(double v) => v.toStringAsFixed(2).replaceAll('.', ',').replaceAll(',00', '');

  @override
  void initState() {
    super.initState();
    final d = widget.deuda;
    _tipo = d?.tipo ?? TipoDeuda.tarjeta;
    _usuarioId = d?.usuarioId ?? miUsuarioId;
    _diaPago = d?.diaPago;
    if (d != null) {
      _nombre.text = d.nombre;
      _saldo.text = _numero(d.saldoInicial);
      if (d.limite != null) _limite.text = _numero(d.limite!);
    }
  }

  Future<void> _hacer(Future<void> Function() accion, {int cerrar = 1}) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) {
        for (var i = 0; i < cerrar; i++) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle un nombre, p. ej. "Visa".')));
      return;
    }
    final saldo = _saldo.text.trim().isEmpty ? 0.0 : leerMonto(_saldo.text);
    final limite = _limite.text.trim().isEmpty ? null : leerMonto(_limite.text);
    if (saldo == null || (_limite.text.trim().isNotEmpty && limite == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa las cantidades.')));
      return;
    }
    _hacer(
      () => widget.datos.guardarDeuda(
        id: widget.deuda?.id,
        usuarioId: _usuarioId,
        nombre: nombre,
        tipo: _tipo,
        limite: _tipo == TipoDeuda.tarjeta ? limite : null,
        saldoInicial: saldo,
        diaPago: _diaPago,
      ),
    );
  }

  Future<void> _borrar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar esta deuda?'),
        content: const Text('Se borran también sus pagos. Los gastos pagados con ella se quedan como gastos normales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (si == true) _hacer(() => widget.datos.borrarDeuda(widget.deuda!.id), cerrar: 2);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final editando = widget.deuda != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Cambiar deuda' : 'Nueva tarjeta o deuda'),
        actions: [
          if (editando) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _ocupado ? null : _borrar),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TipoDeuda>(
            segments: [
              for (final tipo in TipoDeuda.values)
                ButtonSegment(
                  value: tipo,
                  icon: Icon(iconosTipoDeuda[tipo]),
                  label: Text(switch (tipo) {
                    TipoDeuda.tarjeta => 'Tarjeta',
                    TipoDeuda.prestamo => 'Préstamo',
                    TipoDeuda.otra => 'Otra',
                  }),
                ),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: _tipo == TipoDeuda.tarjeta ? 'Ej.: Visa del banco' : 'Ej.: Préstamo del coche',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('¿De quién es?', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in widget.datos.miembros)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: m.color, radius: 8),
                  label: Text(m.usuarioId == miUsuarioId ? '${m.nombre} (yo)' : m.nombre),
                  selected: _usuarioId == m.usuarioId,
                  onSelected: (_) => setState(() => _usuarioId = m.usuarioId),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _saldo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: editando ? 'Lo que se debía al empezar' : '¿Cuánto se debe ahora?',
              prefixText: '${widget.datos.hogar!.moneda} ',
              helperText: 'Luego se irá actualizando con las compras y los pagos',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_tipo == TipoDeuda.tarjeta) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _limite,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Límite de la tarjeta (opcional)',
                prefixText: '${widget.datos.hogar!.moneda} ',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<int?>(
            initialValue: _diaPago,
            decoration: const InputDecoration(labelText: 'Día de pago de cada mes', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin día fijo')),
              for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Día $d')),
            ],
            onChanged: (v) => setState(() => _diaPago = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _ocupado ? null : _guardar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
