import 'package:flutter/material.dart';

import '../datos.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _registro = false;
  bool _ocupado = false;
  bool _verClave = false;
  String? _error;

  Future<void> _enviar() async {
    final correo = _correo.text.trim();
    final clave = _clave.text;
    if (correo.isEmpty || clave.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (_registro) {
        final r = await supabase.auth.signUp(email: correo, password: clave);
        if (r.session == null && mounted) {
          setState(() => _error = 'Cuenta creada. Revisa tu correo para confirmarla y luego pulsa "Entrar".');
        }
      } else {
        await supabase.auth.signInWithPassword(email: correo, password: clave);
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.account_balance_wallet, size: 72, color: colores.primary),
                  const SizedBox(height: 12),
                  Text('Finanzas del Hogar',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Las cuentas de casa, entre todos',
                      textAlign: TextAlign.center, style: TextStyle(color: colores.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Entrar')),
                      ButtonSegment(value: true, label: Text('Crear cuenta')),
                    ],
                    selected: {_registro},
                    onSelectionChanged: (s) => setState(() {
                      _registro = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clave,
                    obscureText: !_verClave,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      labelText: _registro ? 'Contraseña (mínimo 6 caracteres)' : 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _verClave = !_verClave),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colores.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ocupado ? null : _enviar,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _ocupado
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registro ? 'Crear cuenta' : 'Entrar'),
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
