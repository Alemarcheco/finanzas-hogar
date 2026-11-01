import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos.dart';

/// Recuperar la contraseña: se envía un código al correo, se escribe el código
/// y luego la contraseña nueva.
class PantallaRecuperarClave extends StatefulWidget {
  const PantallaRecuperarClave({super.key, this.correoInicial = ''});

  final String correoInicial;

  @override
  State<PantallaRecuperarClave> createState() => _PantallaRecuperarClaveState();
}

enum _Paso { correo, codigo, clave }

class _PantallaRecuperarClaveState extends State<PantallaRecuperarClave> {
  late final _correo = TextEditingController(text: widget.correoInicial);
  final _codigo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  _Paso _paso = _Paso.correo;
  bool _ocupado = false;
  bool _verClave = false;
  String? _error;
  String? _aviso;

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
      _aviso = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _enviarCodigo() async {
    final correo = _correo.text.trim();
    if (!correo.contains('@')) {
      setState(() => _error = 'Escribe el correo de tu cuenta.');
      return;
    }
    await _hacer(() async {
      await supabase.auth.resetPasswordForEmail(correo);
      if (!mounted) return;
      setState(() {
        _paso = _Paso.codigo;
        _aviso = 'Te enviamos un código a $correo. Revisa también la carpeta de spam.';
      });
    });
  }

  Future<void> _comprobarCodigo() async {
    final codigo = _codigo.text.replaceAll(RegExp(r'\s'), '');
    if (codigo.length < 6) {
      setState(() => _error = 'Escribe el código que te llegó al correo.');
      return;
    }
    await _hacer(() async {
      await supabase.auth.verifyOTP(email: _correo.text.trim(), token: codigo, type: OtpType.recovery);
      if (mounted) setState(() => _paso = _Paso.clave);
    });
  }

  Future<void> _guardarClave() async {
    if (_clave.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_clave.text != _clave2.text) {
      setState(() => _error = 'Las dos contraseñas no coinciden.');
      return;
    }
    await _hacer(() async {
      await supabase.auth.updateUser(UserAttributes(password: _clave.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña cambiada. ¡Listo!')));
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final (titulo, campos, boton, accion) = switch (_paso) {
      _Paso.correo => (
        'Escribe el correo de tu cuenta y te enviaremos un código para crear una contraseña nueva.',
        [
          TextField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _enviarCodigo(),
            decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
          ),
        ],
        'Enviar código',
        _enviarCodigo,
      ),
      _Paso.codigo => (
        'Escribe el código que te llegó al correo.',
        [
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 6),
            onSubmitted: (_) => _comprobarCodigo(),
            decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _ocupado ? null : _enviarCodigo,
              child: const Text('No me llegó, enviar otro código'),
            ),
          ),
        ],
        'Comprobar código',
        _comprobarCodigo,
      ),
      _Paso.clave => (
        'Código correcto. Ahora escribe tu contraseña nueva.',
        [
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
            onSubmitted: (_) => _guardarClave(),
            decoration: const InputDecoration(labelText: 'Repite la contraseña', border: OutlineInputBorder()),
          ),
        ],
        'Guardar contraseña',
        _guardarClave,
      ),
    };

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
                  Icon(Icons.lock_reset, size: 64, color: colores.primary),
                  const SizedBox(height: 16),
                  Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  if (_aviso != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _aviso!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colores.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...campos,
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colores.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ocupado ? null : accion,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _ocupado
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(boton),
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
