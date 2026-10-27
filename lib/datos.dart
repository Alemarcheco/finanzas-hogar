import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'formato.dart';
import 'modelo.dart';

SupabaseClient get supabase => Supabase.instance.client;

/// Solo para pruebas y capturas sin servidor.
String? usuarioDePrueba;

String get miUsuarioId => usuarioDePrueba ?? supabase.auth.currentUser!.id;

/// Traduce los errores del servidor a algo que se entienda.
String mensajeDeError(Object error) {
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (m.contains('already registered')) return 'Ya existe una cuenta con ese correo. Usa "Entrar".';
    if (m.contains('password')) return 'La contraseña debe tener al menos 6 caracteres.';
    if (m.contains('email not confirmed')) return 'Falta confirmar el correo (revisa tu bandeja de entrada).';
    return error.message;
  }
  if (error is PostgrestException) {
    if (error.message.contains('No existe ningún hogar')) return 'No existe ningún hogar con ese código.';
    if (error.message.contains('Ya perteneces')) return 'Ya perteneces a un hogar.';
    return error.message;
  }
  final texto = error.toString();
  if (texto.contains('SocketException') || texto.contains('ClientException')) {
    return 'No hay conexión a internet.';
  }
  return texto;
}

/// Hogar del usuario: datos, miembros y movimientos, actualizados en vivo.
class DatosHogar extends ChangeNotifier {
  Hogar? hogar;
  List<Miembro> miembros = [];
  List<Movimiento> movimientos = [];
  List<Plan> planes = [];
  List<Deuda> deudas = [];
  List<OperacionDeuda> operacionesDeuda = [];
  bool cargando = true;
  String? error;

  final _suscripciones = <StreamSubscription<List<Map<String, dynamic>>>>[];

  /// Busca el hogar del usuario. Si no tiene, [hogar] queda en null.
  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final fila = await supabase.from('miembros').select('hogar_id').eq('usuario_id', miUsuarioId).maybeSingle();
      if (fila == null) {
        hogar = null;
        await _cancelar();
      } else {
        final datos = await supabase.from('hogares').select().eq('id', fila['hogar_id'] as String).single();
        hogar = Hogar.desdeMapa(datos);
        _escuchar(hogar!.id);
      }
    } catch (e) {
      error = mensajeDeError(e);
    }
    cargando = false;
    notifyListeners();
  }

  void _escuchar(String hogarId) {
    _cancelar();
    void escuchar(String tabla, String clave, String orden, void Function(List<Map<String, dynamic>>) alRecibir) {
      _suscripciones.add(
        supabase
            .from(tabla)
            .stream(primaryKey: [clave])
            .eq('hogar_id', hogarId)
            .order(orden, ascending: true)
            .listen(
              (filas) {
                alRecibir(filas);
                error = null;
                notifyListeners();
              },
              onError: (e) {
                error = mensajeDeError(e);
                notifyListeners();
              },
            ),
      );
    }

    escuchar('miembros', 'usuario_id', 'unido_en', (filas) {
      miembros = [
        for (var i = 0; i < filas.length; i++)
          Miembro(
            usuarioId: filas[i]['usuario_id'] as String,
            nombre: filas[i]['nombre'] as String,
            color: coloresPersona[i % coloresPersona.length],
          ),
      ];
    });
    escuchar('movimientos', 'id', 'fecha', (filas) {
      movimientos = filas.map(Movimiento.desdeMapa).toList()
        ..sort((a, b) {
          final porFecha = b.fecha.compareTo(a.fecha);
          return porFecha != 0 ? porFecha : b.id.compareTo(a.id);
        });
    });
    escuchar('planes', 'id', 'creado_en', (filas) => planes = filas.map(Plan.desdeMapa).toList());
    escuchar('deudas', 'id', 'creado_en', (filas) => deudas = filas.map(Deuda.desdeMapa).toList());
    escuchar('operaciones_deuda', 'id', 'fecha', (filas) {
      operacionesDeuda = filas.map(OperacionDeuda.desdeMapa).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
    });
  }

  Future<void> _cancelar() async {
    final viejas = [..._suscripciones];
    _suscripciones.clear();
    for (final s in viejas) {
      await s.cancel();
    }
    miembros = [];
    movimientos = [];
    planes = [];
    deudas = [];
    operacionesDeuda = [];
  }

  Miembro miembro(String usuarioId) => miembros.firstWhere(
    (m) => m.usuarioId == usuarioId,
    orElse: () => Miembro(usuarioId: usuarioId, nombre: 'Antiguo miembro', color: const Color(0xFF9E9E9E)),
  );

  Future<void> crearHogar(String nombre, String moneda, String miNombre) async {
    await supabase.rpc('crear_hogar', params: {'p_nombre': nombre, 'p_moneda': moneda, 'p_mi_nombre': miNombre});
    await cargar();
  }

  Future<void> unirseHogar(String codigo, String miNombre) async {
    await supabase.rpc('unirse_hogar', params: {'p_codigo': codigo, 'p_mi_nombre': miNombre});
    await cargar();
  }

  Future<void> salirDelHogar() async {
    await supabase.rpc('salir_hogar');
    await cargar();
  }

  Future<void> cambiarHogar({required String nombre, required String moneda}) async {
    await supabase.from('hogares').update({'nombre': nombre, 'moneda': moneda}).eq('id', hogar!.id);
    await cargar();
  }

  Future<void> cambiarMiNombre(String nombre) async {
    await supabase.from('miembros').update({'nombre': nombre}).eq('usuario_id', miUsuarioId);
  }

  Future<void> guardarMovimiento({
    String? id,
    required TipoMovimiento tipo,
    required String categoria,
    required double monto,
    required String nota,
    required DateTime fecha,
    String? deudaId,
  }) async {
    final datos = {
      'tipo': tipo.name,
      'categoria': categoria,
      'monto': monto,
      'nota': nota,
      'fecha': fechaIso(fecha),
      'deuda_id': tipo == TipoMovimiento.gasto ? deudaId : null,
    };
    if (id == null) {
      await supabase.from('movimientos').insert({...datos, 'hogar_id': hogar!.id, 'usuario_id': miUsuarioId});
    } else {
      await supabase.from('movimientos').update(datos).eq('id', id);
    }
  }

  Future<void> borrarMovimiento(String id) async {
    await supabase.from('movimientos').delete().eq('id', id);
  }

  double saldoDeuda(Deuda d) => d.saldo(movimientos, operacionesDeuda);

  Deuda? deuda(String? id) {
    for (final d in deudas) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> guardarPlan({
    String? id,
    required DateTime mes,
    required TipoMovimiento tipo,
    required String categoria,
    required double monto,
    required String nota,
  }) async {
    final datos = {
      'mes': fechaIso(DateTime(mes.year, mes.month)),
      'tipo': tipo.name,
      'categoria': categoria,
      'monto': monto,
      'nota': nota,
    };
    if (id == null) {
      await supabase.from('planes').insert({...datos, 'hogar_id': hogar!.id, 'usuario_id': miUsuarioId});
    } else {
      await supabase.from('planes').update(datos).eq('id', id);
    }
  }

  Future<void> borrarPlan(String id) async {
    await supabase.from('planes').delete().eq('id', id);
  }

  /// Copia al mes [destino] todo lo previsto en el mes anterior.
  Future<int> copiarPlanDelMesAnterior(DateTime destino) async {
    final anterior = DateTime(destino.year, destino.month - 1);
    final filas = [
      for (final p in planes.where((p) => p.esDelMes(anterior)))
        {
          'hogar_id': hogar!.id,
          'usuario_id': miUsuarioId,
          'mes': fechaIso(DateTime(destino.year, destino.month)),
          'tipo': p.tipo.name,
          'categoria': p.categoria,
          'monto': p.monto,
          'nota': p.nota,
        },
    ];
    if (filas.isNotEmpty) await supabase.from('planes').insert(filas);
    return filas.length;
  }

  Future<void> guardarDeuda({
    String? id,
    required String usuarioId,
    required String nombre,
    required TipoDeuda tipo,
    required double? limite,
    required double saldoInicial,
    required int? diaPago,
  }) async {
    final datos = {
      'usuario_id': usuarioId,
      'nombre': nombre,
      'tipo': tipo.name,
      'limite': limite,
      'saldo_inicial': saldoInicial,
      'dia_pago': diaPago,
    };
    if (id == null) {
      await supabase.from('deudas').insert({...datos, 'hogar_id': hogar!.id});
    } else {
      await supabase.from('deudas').update(datos).eq('id', id);
    }
  }

  Future<void> borrarDeuda(String id) async {
    await supabase.from('deudas').delete().eq('id', id);
  }

  /// Anota un pago o un cargo. Si [tambienComoGasto], el pago cuenta además
  /// como gasto del mes en "Deudas / Préstamos".
  Future<void> anotarOperacionDeuda({
    required Deuda deuda,
    required bool esPago,
    required double monto,
    required String nota,
    required DateTime fecha,
    bool tambienComoGasto = false,
  }) async {
    await supabase.from('operaciones_deuda').insert({
      'hogar_id': hogar!.id,
      'deuda_id': deuda.id,
      'usuario_id': miUsuarioId,
      'tipo': esPago ? 'pago' : 'cargo',
      'monto': monto,
      'nota': nota,
      'fecha': fechaIso(fecha),
    });
    if (esPago && tambienComoGasto) {
      await guardarMovimiento(
        tipo: TipoMovimiento.gasto,
        categoria: 'deudas',
        monto: monto,
        nota: nota.isEmpty ? 'Pago ${deuda.nombre}' : nota,
        fecha: fecha,
      );
    }
  }

  Future<void> borrarOperacionDeuda(String id) async {
    await supabase.from('operaciones_deuda').delete().eq('id', id);
  }

  @override
  void dispose() {
    _cancelar();
    super.dispose();
  }
}
