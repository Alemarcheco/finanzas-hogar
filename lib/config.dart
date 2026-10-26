// Datos de conexión con Supabase.
// Se encuentran en Supabase > Project Settings > API Keys / Data API.
// La clave "anon" / "publishable" es pública: está pensada para ir dentro
// de la app. Los permisos de verdad los pone supabase/esquema.sql.
const supabaseUrl = '';
const supabaseKey = '';

bool get servidorConfigurado => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
