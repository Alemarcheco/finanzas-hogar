import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import '../widgets/pedir_cuenta.dart';
import '../widgets/selector_categoria.dart';
import 'movimientos.dart';

class PantallaEditarMovimiento extends StatefulWidget {
  final DatosHogar datos;
  final Movimiento? movimiento;

  /// Mes que se estaba mirando al pulsar "Anotar": si no es el actual, la fecha empieza en ese mes.
  final DateTime? mes;

  const PantallaEditarMovimiento({super.key, required this.datos, this.movimiento, this.mes});

  @override
  State<PantallaEditarMovimiento> createState() => _PantallaEditarMovimientoState();
}

class _PantallaEditarMovimientoState extends State<PantallaEditarMovimiento> {
  late TipoMovimiento _tipo;
  late String _categoria;
  late DateTime _fecha;
  String? _deudaId;
  String? _cuenta;
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    _tipo = m?.tipo ?? TipoMovimiento.gasto;
    _categoria = m?.categoria ?? categoriasGasto.first.clave;
    _fecha = m?.fecha ?? fechaInicialPara(widget.mes, DateTime.now());
    _deudaId = m?.deudaId;
    _cuenta = m?.cuenta;
    if (m != null) {
      _monto.text = m.monto.abs().toStringAsFixed(2).replaceAll('.', ',').replaceAll(',00', '');
      _nota.text = m.nota;
      // En el ahorro el signo indica si se guarda o se saca.
      if (m.tipo == TipoMovimiento.ahorro) _categoria = m.monto < 0 ? 'retirar' : 'guardar';
    }
  }

  List<Deuda> get _tarjetas => [
    for (final d in widget.datos.deudas)
      if (d.tipo == TipoDeuda.tarjeta || d.id == _deudaId) d,
  ];

  List<String> get _cuentas => [
    ...widget.datos.cuentas,
    if (_cuenta != null && !widget.datos.cuentas.contains(_cuenta)) _cuenta!,
  ];

  Future<void> _nuevaCuenta() async {
    final elegido = await pedirNombreCuenta(context);
    if (elegido != null) {
      setState(() {
        _cuenta = elegido;
        _deudaId = null;
      });
    }
  }

  Widget _selectorCuenta(TextTheme t, ColorScheme c) {
    final esGasto = _tipo == TipoMovimiento.gasto;
    String quien(String usuarioId) => widget.datos.miembro(usuarioId).nombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(esGasto ? '¿Cómo lo pagaste?' : '¿A qué cuenta entró?', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.payments, size: 18),
              label: Text(esGasto ? 'Efectivo' : 'Efectivo / sin indicar'),
              selected: _cuenta == null && _deudaId == null,
              onSelected: (_) => setState(() {
                _cuenta = null;
                _deudaId = null;
              }),
            ),
            for (final cuenta in _cuentas)
              ChoiceChip(
                avatar: const Icon(Icons.account_balance, size: 18),
                label: Text(cuenta),
                selected: _cuenta == cuenta && _deudaId == null,
                onSelected: (_) => setState(() {
                  _cuenta = cuenta;
                  _deudaId = null;
                }),
              ),
            if (esGasto)
              for (final d in _tarjetas)
                ChoiceChip(
                  avatar: Icon(iconosTipoDeuda[d.tipo], size: 18),
                  label: Text('${d.nombre} (${quien(d.usuarioId)})'),
                  selected: _deudaId == d.id,
                  onSelected: (_) => setState(() {
                    _deudaId = d.id;
                    _cuenta = null;
                  }),
                ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nueva cuenta de débito'),
              onPressed: _nuevaCuenta,
            ),
          ],
        ),
        if (esGasto && _deudaId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Se sumará a lo que se debe de esa tarjeta.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  void _cambiarTipo(TipoMovimiento tipo) {
    setState(() {
      _tipo = tipo;
      if (!categoriasDe(tipo).any((c) => c.clave == _categoria)) _categoria = categoriasDe(tipo).first.clave;
    });
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final monto = leerMonto(_monto.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe una cantidad mayor que cero.')));
      return;
    }
    setState(() => _ocupado = true);
    try {
      await widget.datos.guardarMovimiento(
        id: widget.movimiento?.id,
        tipo: _tipo,
        categoria: _categoria,
        monto: _tipo == TipoMovimiento.ahorro && _categoria == 'retirar' ? -monto : monto,
        nota: _nota.text.trim(),
        fecha: _fecha,
        deudaId: _deudaId,
        cuenta: _tipo == TipoMovimiento.ahorro ? null : _cuenta,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  Future<void> _borrar() async {
    if (!await confirmarBorrado(context)) return;
    setState(() => _ocupado = true);
    try {
      await widget.datos.borrarMovimiento(widget.movimiento!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final editando = widget.movimiento != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Cambiar movimiento' : 'Anotar'),
        actions: [
          if (editando) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _ocupado ? null : _borrar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TipoMovimiento>(
            segments: const [
              ButtonSegment(value: TipoMovimiento.gasto, label: Text('Gasto'), icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: TipoMovimiento.ingreso, label: Text('Ingreso'), icon: Icon(Icons.arrow_downward)),
              ButtonSegment(value: TipoMovimiento.ahorro, label: Text('Ahorro'), icon: Icon(Icons.savings)),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => _cambiarTipo(s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _monto,
            autofocus: !editando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: t.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              prefixText: '${widget.datos.hogar!.moneda} ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(_tipo == TipoMovimiento.ahorro ? '¿Guardar o sacar?' : 'Categoría', style: t.titleSmall),
          const SizedBox(height: 8),
          SelectorCategoria(
            categorias: categoriasDe(_tipo),
            elegida: _categoria,
            alElegir: (clave) => setState(() => _categoria = clave),
          ),
          if (_tipo != TipoMovimiento.ahorro) _selectorCuenta(t, c),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(fechaDia(_fecha)),
            trailing: const Icon(Icons.edit),
            onTap: _elegirFecha,
          ),
          TextField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Ej.: compra del mercado',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _ocupado ? null : _guardar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _ocupado
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
