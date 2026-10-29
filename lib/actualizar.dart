import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'recargar_stub.dart' if (dart.library.js_interop) 'recargar_web.dart';

/// Cada APK que compila GitHub se publica como "release" con la etiqueta
/// `v` + número de compilación (p. ej. `v12`). La app compara ese número con el suyo.
const _ultimaVersion = 'https://api.github.com/repos/Alemarcheco/finanzas-hogar/releases/latest';

class VersionNueva {
  final int numero;
  final String enlaceApk;

  const VersionNueva(this.numero, this.enlaceApk);
}

Future<int> numeroInstalado() async => int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

/// Número de una etiqueta "v12" → 12.
int? numeroDeEtiqueta(String etiqueta) => int.tryParse(etiqueta.replaceFirst(RegExp(r'^v'), ''));

/// Devuelve la versión publicada si es más nueva que la instalada.
Future<VersionNueva?> buscarVersionNueva() async {
  final respuesta = await http
      .get(Uri.parse(_ultimaVersion), headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 15));
  if (respuesta.statusCode == 404) return null;
  if (respuesta.statusCode != 200) throw Exception('GitHub respondió ${respuesta.statusCode}');
  final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
  final numero = numeroDeEtiqueta(datos['tag_name'] as String? ?? '');
  final apk = (datos['assets'] as List? ?? [])
      .cast<Map<String, dynamic>>()
      .where((a) => (a['name'] as String).endsWith('.apk'))
      .firstOrNull;
  if (numero == null || apk == null) return null;
  if (numero <= await numeroInstalado()) return null;
  return VersionNueva(numero, apk['browser_download_url'] as String);
}

/// Busca y, si hay versión nueva, ofrece descargarla.
/// Con [silencioso] no avisa cuando ya está al día ni si falla la conexión.
Future<void> comprobarActualizacion(BuildContext context, {bool silencioso = false}) async {
  final mensajero = ScaffoldMessenger.of(context);
  if (kIsWeb) {
    // La web siempre sirve la última versión publicada: basta con recargar.
    recargarPagina();
    return;
  }
  VersionNueva? nueva;
  try {
    nueva = await buscarVersionNueva();
  } catch (_) {
    if (!silencioso) {
      mensajero.showSnackBar(const SnackBar(content: Text('No se pudo comprobar. Revisa la conexión a internet.')));
    }
    return;
  }
  if (nueva == null) {
    if (!silencioso) mensajero.showSnackBar(const SnackBar(content: Text('Ya tienes la última versión.')));
    return;
  }
  if (!context.mounted) return;
  final descargar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.system_update),
      title: const Text('Hay una versión nueva'),
      content: const Text(
        'Se descargará el archivo de instalación. Cuando termine, ábrelo y pulsa "Actualizar". '
        'Tus datos no se pierden: están guardados en el servidor.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Más tarde')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Descargar')),
      ],
    ),
  );
  if (descargar == true) {
    await launchUrl(Uri.parse(nueva.enlaceApk), mode: LaunchMode.externalApplication);
  }
}
