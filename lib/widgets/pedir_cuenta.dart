import 'package:flutter/material.dart';

/// Pide el nombre de una cuenta o tarjeta de débito nueva. Devuelve null si se cancela.
Future<String?> pedirNombreCuenta(BuildContext context) async {
  final nombre = TextEditingController();
  final elegido = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nueva cuenta o tarjeta de débito'),
      content: TextField(
        controller: nombre,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: BBVA débito, Nómina Santander'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(nombre.text.trim()), child: const Text('Añadir')),
      ],
    ),
  );
  return elegido == null || elegido.isEmpty ? null : elegido;
}
