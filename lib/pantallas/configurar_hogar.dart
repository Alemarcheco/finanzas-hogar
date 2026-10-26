import 'package:flutter/material.dart';

import '../datos.dart';

const monedasDisponibles = ['\$', '€', 'CUP', 'USD', 'MXN', 'COP', 'ARS', 'S/', 'Bs'];

/// Primera vez: crear un hogar nuevo o unirse al de la pareja con su código.
class PantallaConfigurarHogar extends StatefulWidget {
  final DatosHogar datos;

  const PantallaConfigurarHogar({super.key, required this.datos});

  @override
  State<PantallaConfigurarHogar> createState() => _PantallaConfigurarHogarState();
}

class _PantallaConfigurarHogarState extends State<PantallaConfigurarHogar> {
  final _miNombre = TextEditingController();
  final _nombreHogar = TextEditingController(text: 'Nuestra casa');
  final _codigo = TextEditingController();
  String _moneda = '\$';
  bool _unirse = false;
  bool _ocupado = false;
  String? _error;



  Future<void> _continuar() async {
    final miNombre = _miNombre.text.trim();
    if (miNombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre.');
      return;
    }
    if (_unirse && _codigo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el código del hogar.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (_unirse) {
        await widget.datos.unirseHogar(_codigo.text, miNombre);
      } else {
        final nombre = _nombreHogar.text.trim().isEmpty ? 'Nuestra casa' : _nombreHogar.text.trim();
        await widget.datos.crearHogar(nombre, _moneda, miNombre);
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu hogar'),
        actions: [
          TextButton(onPressed: () => supabase.auth.signOut(), child: const Text('Salir')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('¿Cómo te llamas?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _miNombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
              helperText: 'Así te verá la otra persona del hogar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Crear hogar'), icon: Icon(Icons.add_home)),
              ButtonSegment(value: true, label: Text('Unirme'), icon: Icon(Icons.group_add)),
            ],
            selected: {_unirse},
            onSelectionChanged: (s) => setState(() {
              _unirse = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 20),
          if (_unirse) ...[
            Text('Pide el código a quien creó el hogar. Lo encuentra en la pestaña "Hogar" de su app.',
                style: TextStyle(color: colores.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código del hogar', border: OutlineInputBorder()),
            ),
          ] else ...[
            Text('Crea el hogar y después comparte el código con tu pareja para que se una desde su teléfono.',
                style: TextStyle(color: colores.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreHogar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre del hogar', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text('Moneda', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in monedasDisponibles)
                  ChoiceChip(label: Text(m), selected: _moneda == m, onSelected: (_) => setState(() => _moneda = m)),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colores.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _ocupado ? null : _continuar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _ocupado
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_unirse ? 'Unirme al hogar' : 'Crear hogar'),
          ),
        ],
      ),
    );
  }
}
