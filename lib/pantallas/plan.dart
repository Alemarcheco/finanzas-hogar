import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import '../widgets/selector_categoria.dart';
import 'resumen.dart';

const _titulos = {
  TipoMovimiento.ingreso: 'Ingresos previstos',
  TipoMovimiento.gasto: 'Gastos previstos',
  TipoMovimiento.ahorro: 'Ahorro previsto',
};

Future<void> abrirEditorPlan(
  BuildContext context,
  DatosHogar datos,
  DateTime mes, {
  Plan? plan,
  TipoMovimiento? tipo,
  String? categoria,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PantallaEditarPlan(datos: datos, mes: mes, plan: plan, tipo: tipo, categoria: categoria),
      fullscreenDialog: true,
    ),
  );
}

/// Lo que está previsto para el mes frente a lo que de verdad se lleva.
class PestanaPlan extends StatelessWidget {
  final DatosHogar datos;
  final DateTime mes;

  const PestanaPlan({super.key, required this.datos, required this.mes});

  Future<void> _copiarAnterior(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final n = await datos.copiarPlanDelMesAnterior(mes);
      mensajero.showSnackBar(SnackBar(content: Text('Copiadas $n partidas del mes anterior')));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneda = datos.hogar!.moneda;
    final r = ResumenPlan.calcular(datos.planes, datos.movimientos, mes);
    final anterior = DateTime(mes.year, mes.month - 1);
    final hayAnterior = datos.planes.any((p) => p.esDelMes(anterior));
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    if (r.vacio) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
        children: [
          Icon(Icons.event_note, size: 64, color: c.outline),
          const SizedBox(height: 12),
          Text(
            'Aún no hay plan para ${nombreMes(mes).toLowerCase()}',
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Anota lo que esperáis cobrar, lo que va a costar la renta, la comida, la luz… '
            'y lo que queréis ahorrar. Luego verás cuánto lleváis gastado de cada cosa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir al plan'),
            onPressed: () => abrirEditorPlan(context, datos, mes),
          ),
          if (hayAnterior) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_all),
              label: Text('Copiar el plan de ${nombreMes(anterior).toLowerCase()}'),
              onPressed: () => _copiarAnterior(context),
            ),
          ],
        ],
      );
    }

    final gastoPrevisto = r.previsto(TipoMovimiento.gasto);
    final gastoReal = r.real(TipoMovimiento.gasto);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          color: c.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si todo va según el plan, quedará libre',
                  style: t.titleSmall?.copyWith(color: c.onPrimaryContainer),
                ),
                FittedBox(
                  child: Text(
                    dinero(r.librePrevisto, moneda),
                    style: t.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: r.librePrevisto < 0 ? rojoGasto : c.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Dato('Ingresos', r.previsto(TipoMovimiento.ingreso), moneda, verdeIngreso),
                    _Dato('Gastos', gastoPrevisto, moneda, rojoGasto),
                    _Dato('Ahorro', r.previsto(TipoMovimiento.ahorro), moneda, azulAhorro),
                  ],
                ),
                if (gastoPrevisto > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Gastado ${dinero(gastoReal, moneda)} de ${dinero(gastoPrevisto, moneda)} previstos',
                    style: t.bodyMedium?.copyWith(color: c.onPrimaryContainer),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (gastoReal / gastoPrevisto).clamp(0, 1).toDouble(),
                      minHeight: 10,
                      color: gastoReal > gastoPrevisto ? rojoGasto : c.primary,
                      backgroundColor: c.surface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hayAnterior)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all, size: 18),
              label: Text('Copiar lo de ${nombreMes(anterior).toLowerCase()}'),
              onPressed: () => _copiarAnterior(context),
            ),
          ),
        for (final tipo in [TipoMovimiento.gasto, TipoMovimiento.ingreso, TipoMovimiento.ahorro])
          if (r.lineas[tipo]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Row(
                children: [
                  Expanded(child: Text(_titulos[tipo]!, style: t.titleMedium)),
                  Text('${dinero(r.real(tipo), moneda)} / ${dinero(r.previsto(tipo), moneda)}', style: t.labelMedium),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [for (final l in r.lineas[tipo]!) _FilaPlan(linea: l, datos: datos, mes: mes)],
              ),
            ),
          ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final double valor;
  final String moneda;
  final Color color;

  const _Dato(this.titulo, this.valor, this.moneda, this.color);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
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

class _FilaPlan extends StatelessWidget {
  final LineaPlan linea;
  final DatosHogar datos;
  final DateTime mes;

  const _FilaPlan({required this.linea, required this.datos, required this.mes});

  @override
  Widget build(BuildContext context) {
    final cat = linea.tipo == TipoMovimiento.ahorro
        ? const Categoria('guardar', 'Ahorro', Icons.savings, azulAhorro)
        : categoriaPorClave(linea.categoria);
    final moneda = datos.hogar!.moneda;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final esGasto = linea.tipo == TipoMovimiento.gasto;
    final pasado = esGasto && linea.real - linea.previsto >= 0.005;

    final resta = linea.previsto - linea.real;
    final justo = resta.abs() < 0.005;
    final String estado;
    Color colorEstado = c.onSurfaceVariant;
    if (linea.previsto == 0) {
      estado = 'Sin plan';
      colorEstado = esGasto ? rojoGasto : c.onSurfaceVariant;
    } else if (justo) {
      estado = 'Justo lo previsto';
      if (!esGasto) colorEstado = verdeIngreso;
    } else if (esGasto) {
      estado = pasado ? 'Te pasaste ${dinero(-resta, moneda)}' : 'Quedan ${dinero(resta, moneda)}';
      if (pasado) colorEstado = rojoGasto;
    } else {
      estado = resta <= 0 ? '¡Conseguido!' : 'Faltan ${dinero(resta, moneda)}';
      if (resta <= 0) colorEstado = verdeIngreso;
    }

    return InkWell(
      onTap: () => _verPartidas(context, cat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cat.color,
              foregroundColor: Colors.white,
              child: Icon(cat.icono, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(cat.nombre)),
                      Text(
                        '${dinero(linea.real, moneda)} / ${dinero(linea.previsto, moneda)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: linea.avance.clamp(0, 1).toDouble(),
                      minHeight: 6,
                      color: pasado ? rojoGasto : cat.color,
                      backgroundColor: c.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(estado, style: t.bodySmall?.copyWith(color: colorEstado)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verPartidas(BuildContext context, Categoria cat) {
    final moneda = datos.hogar!.moneda;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(cat.nombre, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            if (linea.partidas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('No hay nada previsto en esta categoría.'),
              ),
            for (final p in linea.partidas)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(p.nota.isEmpty ? cat.nombre : p.nota),
                trailing: Text(dinero(p.monto, moneda), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(hoja);
                  abrirEditorPlan(context, datos, mes, plan: p);
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Añadir a esta categoría'),
                onPressed: () {
                  Navigator.pop(hoja);
                  abrirEditorPlan(context, datos, mes, tipo: linea.tipo, categoria: linea.categoria);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PantallaEditarPlan extends StatefulWidget {
  final DatosHogar datos;
  final DateTime mes;
  final Plan? plan;
  final TipoMovimiento? tipo;
  final String? categoria;

  const PantallaEditarPlan({super.key, required this.datos, required this.mes, this.plan, this.tipo, this.categoria});

  @override
  State<PantallaEditarPlan> createState() => _PantallaEditarPlanState();
}

class _PantallaEditarPlanState extends State<PantallaEditarPlan> {
  late TipoMovimiento _tipo;
  late String _categoria;
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  bool _ocupado = false;

  List<Categoria> _categorias(TipoMovimiento t) =>
      t == TipoMovimiento.ahorro ? categoriasAhorro.take(1).toList() : categoriasDe(t);

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _tipo = p?.tipo ?? widget.tipo ?? TipoMovimiento.gasto;
    _categoria = p?.categoria ?? widget.categoria ?? _categorias(_tipo).first.clave;
    if (p != null) {
      _monto.text = p.monto.toStringAsFixed(2).replaceAll('.', ',').replaceAll(',00', '');
      _nota.text = p.nota;
    }
  }

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  void _guardar() {
    final monto = leerMonto(_monto.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe una cantidad mayor que cero.')));
      return;
    }
    _hacer(
      () => widget.datos.guardarPlan(
        id: widget.plan?.id,
        mes: widget.mes,
        tipo: _tipo,
        categoria: _categoria,
        monto: monto,
        nota: _nota.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final editando = widget.plan != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Plan de ${nombreMes(widget.mes).toLowerCase()}'),
        actions: [
          if (editando)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _ocupado ? null : () => _hacer(() => widget.datos.borrarPlan(widget.plan!.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TipoMovimiento>(
            segments: const [
              ButtonSegment(value: TipoMovimiento.gasto, label: Text('Gasto')),
              ButtonSegment(value: TipoMovimiento.ingreso, label: Text('Ingreso')),
              ButtonSegment(value: TipoMovimiento.ahorro, label: Text('Ahorro')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() {
              _tipo = s.first;
              if (!_categorias(_tipo).any((c) => c.clave == _categoria)) _categoria = _categorias(_tipo).first.clave;
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _monto,
            autofocus: !editando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: t.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Cantidad prevista',
              prefixText: '${widget.datos.hogar!.moneda} ',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_tipo != TipoMovimiento.ahorro) ...[
            const SizedBox(height: 20),
            Text('Categoría', style: t.titleSmall),
            const SizedBox(height: 8),
            SelectorCategoria(
              categorias: _categorias(_tipo),
              elegida: _categoria,
              alElegir: (clave) => setState(() => _categoria = clave),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Ej.: renta del piso, salario de María…',
              border: OutlineInputBorder(),
            ),
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
