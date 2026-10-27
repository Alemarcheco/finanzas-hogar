# Finanzas del Hogar

App Flutter (Android, iPhone por el navegador e iOS) para llevar las cuentas de casa entre varias personas.
Cada persona entra con su propia cuenta desde su teléfono y todo se suma en el mismo hogar.

- **Resumen del mes**: lo que queda libre, ingresos, gastos, lo ahorrado y el ahorro acumulado.
- **¿En qué se fue el dinero?**: gráfico de gastos por categoría (comida, renta, luz/agua, transporte…).
- **¿Quién gastó qué?**: gasto, ingreso y ahorro de cada persona.
- **Movimientos**: lista por días, con filtros por persona y por tipo. Cada uno puede cambiar o borrar solo lo suyo.
- **Hogar**: código de invitación para que la pareja se una, nombres, moneda.
- Los cambios aparecen al momento en el otro teléfono.

## Servidor (Supabase, gratis)

1. Crea un proyecto en https://supabase.com/dashboard.
2. Abre **SQL Editor**, pega el contenido de [`supabase/esquema.sql`](supabase/esquema.sql) y pulsa **Run**.
3. En **Authentication → Sign In / Providers → Email**, desactiva **Confirm email** y guarda.
4. En **Project Settings → API Keys / Data API** copia la *Project URL* y la clave *anon* / *publishable*
   y ponlas en [`lib/config.dart`](lib/config.dart).

## Versión web (iPhone)

La misma app se publica como página web en GitHub Pages en cada cambio de `main`
(`https://<usuario>.github.io/finanzas-hogar/`). Usa el mismo servidor, así que Android y web ven el mismo hogar.
En el iPhone se abre con Safari y se añade a la pantalla de inicio (Compartir → Añadir a pantalla de inicio).

Para activarlo una vez: **Settings → Pages → Source: GitHub Actions** (el repositorio debe ser público).

## Compilar APK

GitHub Actions compila el APK en cada cambio de `main` (pestaña **Actions → Compilar APK → Artifacts**).

En local:

```
flutter pub get
flutter test
flutter build apk --release
```
