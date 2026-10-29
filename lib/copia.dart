import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'datos.dart';
import 'formato.dart';

/// Copia de seguridad de todo el hogar en un archivo .json.
///
/// Los datos ya viven en el servidor; este archivo es una copia extra por si
/// algún día se pierde el proyecto de Supabase o se quiere pasar a otro.
const versionCopia = 1;

Map<String, dynamic> copiaDelHogar(DatosHogar d, DateTime ahora) => {
  'app': 'finanzas-hogar',
  'version': versionCopia,
  'exportado': ahora.toUtc().toIso8601String(),
  'hogar': {'nombre': d.hogar!.nombre, 'moneda': d.hogar!.moneda},
  'miembros': [
    for (final m in d.miembros) {'usuario_id': m.usuarioId, 'nombre': m.nombre},
  ],
  'movimientos': [
    for (final m in d.movimientos)
      {
        'id': m.id,
        'usuario_id': m.usuarioId,
        'tipo': m.tipo.name,
        'categoria': m.categoria,
        'monto': m.monto,
        'nota': m.nota,
        'fecha': fechaIso(m.fecha),
        'deuda_id': m.deudaId,
      },
  ],
  'planes': [
    for (final p in d.planes)
      {
        'id': p.id,
        'mes': fechaIso(p.mes),
        'tipo': p.tipo.name,
        'categoria': p.categoria,
        'monto': p.monto,
        'nota': p.nota,
      },
  ],
  'deudas': [
    for (final x in d.deudas)
      {
        'id': x.id,
        'usuario_id': x.usuarioId,
        'nombre': x.nombre,
        'tipo': x.tipo.name,
        'limite': x.limite,
        'saldo_inicial': x.saldoInicial,
        'dia_pago': x.diaPago,
      },
  ],
  'operaciones_deuda': [
    for (final o in d.operacionesDeuda)
      {
        'id': o.id,
        'deuda_id': o.deudaId,
        'usuario_id': o.usuarioId,
        'tipo': o.esPago ? 'pago' : 'cargo',
        'monto': o.monto,
        'nota': o.nota,
        'fecha': fechaIso(o.fecha),
      },
  ],
};

/// Comprueba que el archivo es una copia de esta app y la devuelve.
Map<String, dynamic> leerCopia(Uint8List bytes) {
  final Object? datos;
  try {
    datos = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    throw const FormatException('El archivo no es una copia de seguridad válida.');
  }
  if (datos is! Map<String, dynamic> || datos['app'] != 'finanzas-hogar') {
    throw const FormatException('Este archivo no es una copia de Finanzas del Hogar.');
  }
  return datos;
}

/// Abre el menú de compartir del teléfono (Guardar en Archivos, Drive, WhatsApp…).
/// En navegadores que no pueden compartir archivos, se descarga directamente.
Future<void> exportarCopia(DatosHogar d) async {
  final ahora = DateTime.now();
  final nombre = 'finanzas-hogar-${fechaIso(ahora)}.json';
  final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(copiaDelHogar(d, ahora)));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: nombre, mimeType: 'application/json')],
      fileNameOverrides: [nombre],
      subject: 'Copia de seguridad de ${d.hogar!.nombre}',
      downloadFallbackEnabled: true,
      mailToFallbackEnabled: false,
    ),
  );
}

/// Pide un archivo de copia y lo carga en el hogar actual.
/// Devuelve null si se cancela; si no, cuántas cosas se añadieron.
Future<Map<String, dynamic>?> importarCopia(DatosHogar d) async {
  final archivo = await FilePicker.pickFile(dialogTitle: 'Elige la copia de seguridad');
  if (archivo == null) return null;
  final copia = leerCopia(await archivo.readAsBytes());
  final resultado = await supabase.rpc('importar_copia', params: {'p_copia': copia});
  await d.refrescar();
  return Map<String, dynamic>.from(resultado as Map);
}
