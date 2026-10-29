import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../actualizar.dart';
import '../copia.dart';
import '../datos.dart';
import 'configurar_hogar.dart';

class PestanaHogar extends StatelessWidget {
  final DatosHogar datos;

  const PestanaHogar({super.key, required this.datos});

  Future<String?> _pedirTexto(BuildContext context, String titulo, String inicial) {
    final control = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: control, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, control.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _intentar(BuildContext context, Future<void> Function() accion) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await accion();
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _importar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final r = await importarCopia(datos);
      if (r == null) return;
      final total = r.values.fold<int>(0, (s, n) => s + (n as int));
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            total == 0
                ? 'Todo lo de la copia ya estaba en la app.'
                : 'Copia cargada: ${r['movimientos']} movimientos, ${r['planes']} del plan, '
                      '${r['deudas']} deudas y ${r['operaciones']} pagos.',
          ),
        ),
      );
    } on FormatException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hogar = datos.hogar!;
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final yo = datos.miembro(miUsuarioId);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: c.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Código para unirse al hogar', style: t.titleSmall?.copyWith(color: c.onSecondaryContainer)),
                const SizedBox(height: 8),
                SelectableText(
                  hogar.codigo,
                  style: t.displaySmall?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: c.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu pareja instala la app, crea su cuenta, elige "Unirme" y escribe este código.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: c.onSecondaryContainer),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hogar.codigo));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Personas del hogar', style: t.titleMedium),
        for (final m in datos.miembros)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: m.color,
              foregroundColor: Colors.white,
              child: Text(m.nombre.isEmpty ? '?' : m.nombre[0].toUpperCase()),
            ),
            title: Text(m.usuarioId == miUsuarioId ? '${m.nombre} (tú)' : m.nombre),
            trailing: m.usuarioId == miUsuarioId ? const Icon(Icons.edit) : null,
            onTap: m.usuarioId == miUsuarioId
                ? () async {
                    final nuevo = await _pedirTexto(context, 'Tu nombre', yo.nombre);
                    if (nuevo != null && nuevo.isNotEmpty && context.mounted) {
                      await _intentar(context, () => datos.cambiarMiNombre(nuevo));
                    }
                  }
                : null,
          ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.home_work),
          title: const Text('Nombre del hogar'),
          subtitle: Text(hogar.nombre),
          onTap: () async {
            final nuevo = await _pedirTexto(context, 'Nombre del hogar', hogar.nombre);
            if (nuevo != null && nuevo.isNotEmpty && context.mounted) {
              await _intentar(context, () => datos.cambiarHogar(nombre: nuevo, moneda: hogar.moneda));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text('Moneda'),
          subtitle: Text(hogar.moneda),
          onTap: () async {
            final nueva = await showDialog<String>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Moneda'),
                children: [
                  for (final m in monedasDisponibles)
                    SimpleDialogOption(onPressed: () => Navigator.pop(context, m), child: Text(m)),
                ],
              ),
            );
            if (nueva != null && context.mounted) {
              await _intentar(context, () => datos.cambiarHogar(nombre: hogar.nombre, moneda: nueva));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Sesión iniciada como'),
          subtitle: Text(supabase.auth.currentUser?.email ?? ''),
        ),
        const Divider(height: 32),
        Text('Copia de seguridad', style: t.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tus datos ya se guardan en el servidor. Además puedes guardar una copia en un archivo '
          '(en Archivos, Drive, WhatsApp…) y cargarla cuando quieras: no se duplica nada.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Exportar'),
                onPressed: () => _intentar(context, () => exportarCopia(datos)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Importar'),
                onPressed: () => _importar(context),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, info) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.system_update),
            title: Text(kIsWeb ? 'Cargar la última versión' : 'Buscar actualización'),
            subtitle: Text('Versión ${info.data?.version ?? '…'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => comprobarActualizacion(context),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          onPressed: () => supabase.auth.signOut(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(Icons.exit_to_app, color: c.error),
          label: Text('Salir de este hogar', style: TextStyle(color: c.error)),
          onPressed: () async {
            final si = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Salir del hogar?'),
                content: const Text(
                  'Dejarás de ver las cuentas de este hogar. Lo que anotaste se queda para los demás. '
                  'Podrás volver a entrar con el código.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
                ],
              ),
            );
            if (si == true && context.mounted) await _intentar(context, datos.salirDelHogar);
          },
        ),
      ],
    );
  }
}
