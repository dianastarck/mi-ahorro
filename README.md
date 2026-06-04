# Mi Ahorro Native

App Android nativa en Flutter. No es WebView, no carga Netlify como navegador.
Se conecta directo a Supabase usando las tablas existentes `finance_months` y `savings_goals`.

## Compilar APK en GitHub
1. Crear repo nuevo vacío.
2. Subir todo el contenido de esta carpeta, no el ZIP cerrado.
3. Ir a Actions > Build Native Flutter APK > Run workflow.
4. Descargar artifact `mi-ahorro-native-apk`.
5. Descomprimir y usar `app-debug.apk`.
