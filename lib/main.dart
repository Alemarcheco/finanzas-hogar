import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'datos.dart';
import 'pantallas/configurar_hogar.dart';
import 'pantallas/inicio.dart';
import 'pantallas/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  if (servidorConfigurado) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  runApp(const FinanzasHogarApp());
}

class FinanzasHogarApp extends StatelessWidget {
  const FinanzasHogarApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData tema(Brightness brillo) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B), brightness: brillo),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'Finanzas del Hogar',
      debugShowCheckedModeBanner: false,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: servidorConfigurado ? const PuertaSesion() : const _SinServidor(),
    );
  }
}

/// Muestra el login, la elección de hogar o la app según el estado.
class PuertaSesion extends StatelessWidget {
  const PuertaSesion({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final usuario = supabase.auth.currentUser;
        if (usuario == null) return const PantallaLogin();
        return _ConHogar(key: ValueKey(usuario.id));
      },
    );
  }
}

class _ConHogar extends StatefulWidget {
  const _ConHogar({super.key});

  @override
  State<_ConHogar> createState() => _ConHogarState();
}

class _ConHogarState extends State<_ConHogar> {
  final datos = DatosHogar();

  @override
  void initState() {
    super.initState();
    datos.cargar();
  }

  @override
  void dispose() {
    datos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: datos,
      builder: (context, _) {
        if (datos.cargando && datos.hogar == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (datos.hogar == null) {
          if (datos.error != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(datos.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: datos.cargar, child: const Text('Reintentar')),
                    TextButton(onPressed: () => supabase.auth.signOut(), child: const Text('Cerrar sesión')),
                  ]),
                ),
              ),
            );
          }
          return PantallaConfigurarHogar(datos: datos);
        }
        return PantallaInicio(datos: datos);
      },
    );
  }
}

class _SinServidor extends StatelessWidget {
  const _SinServidor();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Falta conectar la app con Supabase.\n\nRellena lib/config.dart con la dirección y la clave del proyecto.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
