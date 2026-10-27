// Datos de conexión con Supabase.
// Se encuentran en Supabase > Project Settings > API Keys / Data API.
// La clave "anon" / "publishable" es pública: está pensada para ir dentro
// de la app. Los permisos de verdad los pone supabase/esquema.sql.
const supabaseUrl = 'https://yoculnxmhhzpqnutjvch.supabase.co';
const supabaseKey = 'sb_publishable_GEWcFBDLUT5wS7iSTRxKYg_o_uBrbwV';

bool get servidorConfigurado => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
