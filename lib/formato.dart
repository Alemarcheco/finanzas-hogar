import 'package:intl/intl.dart';

String dinero(double valor, String moneda) {
  final f = NumberFormat.currency(locale: 'es', symbol: moneda, decimalDigits: 2);
  return f.format(valor);
}

String nombreMes(DateTime mes) {
  final texto = DateFormat('MMMM yyyy', 'es').format(mes);
  return texto[0].toUpperCase() + texto.substring(1);
}

String fechaDia(DateTime fecha) {
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (mismoDia(fecha, hoy)) return 'Hoy';
  if (mismoDia(fecha, ayer)) return 'Ayer';
  final texto = DateFormat('EEEE d MMMM', 'es').format(fecha);
  return texto[0].toUpperCase() + texto.substring(1);
}

String fechaIso(DateTime fecha) => DateFormat('yyyy-MM-dd').format(fecha);

/// Convierte "1.234,50", "1234.5" o "1,5" en número.
double? leerMonto(String texto) {
  var t = texto.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  final coma = t.lastIndexOf(',');
  final punto = t.lastIndexOf('.');
  if (coma >= 0 && punto >= 0) {
    // El último separador es el decimal.
    if (coma > punto) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (coma >= 0) {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t);
}

/// Fecha propuesta al anotar mirando [mes]: hoy si es el mes actual, si no el día 1 de ese mes.
DateTime fechaInicialPara(DateTime? mes, DateTime hoy) {
  if (mes == null || (mes.year == hoy.year && mes.month == hoy.month)) return hoy;
  return DateTime(mes.year, mes.month, 1);
}
