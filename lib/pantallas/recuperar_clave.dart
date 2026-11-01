import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos.dart';

/// Dirección de la versión web: el enlace del correo abre aquí la app
/// para poner la contraseña nueva.
const direccionWeb = 'https://alemarcheco.github.io/finanzas-hogar/';

/// Pide el correo y envía el enlace para crear una contraseña nueva.
class PantallaRecuperarClave extends StatefulWidget {
  const PantallaRecuperarClave({super.key, this.correoInicial = ''});

  final String correoInicial;

  @override
  State<PantallaRecuperarClave> createState() => _PantallaRecuperarClaveState();
}

class _PantallaRecuperarClaveState extends State<PantallaRecuperarClave> {
  late final _correo = TextEditingController(text: widget.correoInicial);
  bool _ocupado = false;
  bool _enviado = false;
  String? _error;

  Future<void> _enviar() async {
    final correo = _correo.text.trim();
    if (!correo.contains('@')) {
      setState(() => _error = 'Escribe el correo de tu cuenta.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await supabase.auth.resetPasswordForEmail(correo, redirectTo: direccionWeb);
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(_enviado ? Icons.mark_email_read : Icons.lock_reset, size: 64, color: colores.primary),
                  const SizedBox(height: 16),
                  if (!_enviado) ...[
                    Text(
                      'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.',
                      textAlign: TextAlign.center,
                      style: texto.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                    ),
                  ] else ...[
                    Text('Revisa tu correo', textAlign: TextAlign.center, style: texto.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                      '1. Abre el correo de Supabase que te llegó a ${_correo.text.trim()} '
                      '(mira también en spam).\n'
                      '2. Toca el enlace "Reset Password".\n'
                      '3. Se abrirá Finanzas del Hogar en el navegador y te pedirá la contraseña nueva.\n'
                      '4. Después vuelve aquí y entra con tu contraseña nueva.',
                      style: texto.bodyLarge,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colores.error)),
                  ],
                  const SizedBox(height: 20),
                  if (!_enviado)
                    FilledButton(
                      onPressed: _ocupado ? null : _enviar,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _ocupado
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar enlace'),
                    )
                  else ...[
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Volver a entrar'),
                    ),
                    TextButton(onPressed: _ocupado ? null : _enviar, child: const Text('No me llegó, enviar otra vez')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Se muestra al abrir el enlace del correo: pide la contraseña nueva.
class PantallaClaveNueva extends StatefulWidget {
  const PantallaClaveNueva({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<PantallaClaveNueva> createState() => _PantallaClaveNuevaState();
}

class _PantallaClaveNuevaState extends State<PantallaClaveNueva> {
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _ocupado = false;
  bool _verClave = false;
  String? _error;

  Future<void> _guardar() async {
    if (_clave.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_clave.text != _clave2.text) {
      setState(() => _error = 'Las dos contraseñas no coinciden.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _clave.text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña cambiada. Ya puedes entrar con ella en el teléfono.')));
      widget.alTerminar();
      return;
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Contraseña nueva')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_reset, size: 64, color: colores.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Escribe tu contraseña nueva.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _clave,
                    obscureText: !_verClave,
                    decoration: InputDecoration(
                      labelText: 'Contraseña nueva (mínimo 6 caracteres)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _verClave = !_verClave),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clave2,
                    obscureText: !_verClave,
                    onSubmitted: (_) => _guardar(),
                    decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colores.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ocupado ? null : _guardar,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _ocupado
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
