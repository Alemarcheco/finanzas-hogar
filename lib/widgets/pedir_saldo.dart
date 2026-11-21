import 'package:flutter/material.dart';

import '../formato.dart';

/// Pregunta cuánto hay (o se debe) de verdad según el banco.
Future<double?> pedirSaldoReal(
  BuildContext context, {
  required String titulo,
  required String pregunta,
  required double saldoApp,
  required String moneda,
}) async {
  final texto = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('La app dice: ${dinero(saldoApp, moneda)}'),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: pregunta, prefixText: '$moneda '),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          Text(
            'La diferencia se anota como "Ajuste de saldo" y no cuenta como ingreso ni gasto del mes.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajustar')),
      ],
    ),
  );
  if (ok != true) return null;
  return leerMonto(texto.text);
}
