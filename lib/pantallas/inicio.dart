import 'package:flutter/material.dart';

import '../datos.dart';
import '../formato.dart';
import 'deudas.dart';
import 'editar_movimiento.dart';
import 'hogar.dart';
import 'movimientos.dart';
import 'plan.dart';
import 'resumen.dart';

class PantallaInicio extends StatefulWidget {
  final DatosHogar datos;

  const PantallaInicio({super.key, required this.datos});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _pestana = 0;
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  void _moverMes(int delta) => setState(() => _mes = DateTime(_mes.year, _mes.month + delta));

  void _nuevo() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PantallaEditarMovimiento(datos: widget.datos), fullscreenDialog: true));
  }

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    final conMes = _pestana < 3;
    final esteMes = DateTime(DateTime.now().year, DateTime.now().month);
    return Scaffold(
      appBar: AppBar(
        title: Text(datos.hogar!.nombre),
        bottom: conMes
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _moverMes(-1)),
                    GestureDetector(
                      onTap: () => setState(() => _mes = esteMes),
                      child: SizedBox(
                        width: 180,
                        child: Text(
                          nombreMes(_mes),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _mes.isBefore(DateTime(esteMes.year + 1, esteMes.month)) ? () => _moverMes(1) : null,
                    ),
                  ],
                ),
              )
            : null,
      ),
      body: ListenableBuilder(
        listenable: datos,
        builder: (context, _) => switch (_pestana) {
          0 => PestanaResumen(datos: datos, mes: _mes, irA: (i) => setState(() => _pestana = i)),
          1 => PestanaMovimientos(datos: datos, mes: _mes),
          2 => PestanaPlan(datos: datos, mes: _mes),
          3 => PestanaDeudas(datos: datos),
          _ => PestanaHogar(datos: datos),
        },
      ),
      floatingActionButton: switch (_pestana) {
        0 ||
        1 => FloatingActionButton.extended(onPressed: _nuevo, icon: const Icon(Icons.add), label: const Text('Anotar')),
        2 => FloatingActionButton.extended(
          onPressed: () => abrirEditorPlan(context, datos, _mes),
          icon: const Icon(Icons.add),
          label: const Text('Al plan'),
        ),
        3 => FloatingActionButton.extended(
          onPressed: () => abrirEditorDeuda(context, datos),
          icon: const Icon(Icons.add),
          label: const Text('Deuda'),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Deudas',
          ),
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hogar'),
        ],
      ),
    );
  }
}
