import 'package:flutter/material.dart';

import '../modelo.dart';

/// Cuadrícula de categorías con su icono y color.
class SelectorCategoria extends StatelessWidget {
  final List<Categoria> categorias;
  final String elegida;
  final ValueChanged<String> alElegir;

  const SelectorCategoria({super.key, required this.categorias, required this.elegida, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        for (final cat in categorias)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => alElegir(cat.clave),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: elegida == cat.clave ? cat.color : c.outlineVariant,
                  width: elegida == cat.clave ? 2.5 : 1,
                ),
                color: elegida == cat.clave ? cat.color.withValues(alpha: 0.12) : null,
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cat.color,
                    foregroundColor: Colors.white,
                    child: Icon(cat.icono, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.nombre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
