import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import '../modelo.dart';
import 'movimientos.dart';

class PantallaEditarMovimiento extends StatefulWidget {
  final DatosHogar datos;
  final Movimiento? movimiento;

  const PantallaEditarMovimiento({super.key, required this.datos, this.movimiento});

  @override
  State<PantallaEditarMovimiento> createState() => _PantallaEditarMovimientoState();
}

class _PantallaEditarMovimientoState extends State<PantallaEditarMovimiento> {
  late TipoMovimiento _tipo;
  late String _categoria;
  late DateTime _fecha;
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    _tipo = m?.tipo ?? TipoMovimiento.gasto;
    _categoria = m?.categoria ?? categoriasGasto.first.clave;
    _fecha = m?.fecha ?? DateTime.now();
    if (m != null) {
      _monto.text = m.monto.abs().toStringAsFixed(2).replaceAll('.', ',').replaceAll(',00', '');
      _nota.text = m.nota;
      // En el ahorro el signo indica si se guarda o se saca.
      if (m.tipo == TipoMovimiento.ahorro) _categoria = m.monto < 0 ? 'retirar' : 'guardar';
    }
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
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              for (final cat in categoriasDe(_tipo))
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _categoria = cat.clave),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _categoria == cat.clave ? cat.color : c.outlineVariant,
                        width: _categoria == cat.clave ? 2.5 : 1,
                      ),
                      color: _categoria == cat.clave ? cat.color.withValues(alpha: 0.12) : null,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: cat.color,
                          foregroundColor: Colors.white,
                          child: Icon(cat.icono, size: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(cat.nombre,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
