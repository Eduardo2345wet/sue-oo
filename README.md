# Sueño

App para iPhone que calcula tu deuda de sueño de las últimas 14 noches, tu curva de energía del día con el modelo SAFTE (modorra, pico de la mañana, bajón de la tarde, pico de la tarde, relajación y ventana de melatonina) y a qué hora acostarte. Trae widget para la pantalla de inicio y de bloqueo, avisos, y acciones para la app Atajos.

Es gratis: se compila en GitHub y se instala con SideStore usando tu Apple ID normal.

## Lo que necesitas

- iPhone con iOS 17 o más nuevo.
- Una cuenta gratis de GitHub.
- Tu Apple ID (el de siempre, sin pagar nada).
- Una computadora con Windows, Mac o Linux, solo para instalar SideStore la primera vez.

## 1. Subir el proyecto a GitHub

1. Entra a github.com y crea una cuenta.
2. Arriba a la derecha, **+ → New repository**. Nombre: `sueno`. Márcalo como **Public** (así la compilación en Mac es gratis). Crea el repositorio.
3. Toca **uploading an existing file** y arrastra **el contenido** de la carpeta `sueno-app` (no la carpeta misma). Luego **Commit changes**.
4. Revisa que exista el archivo `.github/workflows/compilar.yml`. Las carpetas que empiezan con punto a veces no se suben al arrastrar. Si no está: **Add file → Create new file**, escribe `.github/workflows/compilar.yml` como nombre, pega el contenido de ese archivo y haz **Commit**.

Si prefieres la terminal:

```bash
cd sueno-app
git init
git add .
git commit -m "Sueño"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/sueno.git
git push -u origin main
```

El código queda público; tus datos de sueño no, porque viven solo en tu iPhone.

## 2. Compilar el .ipa

1. En tu repositorio, pestaña **Actions → Compilar IPA → Run workflow**. También corre solo cada vez que subes cambios.
2. Tarda entre 5 y 10 minutos. Cuando salga la palomita verde, entra a esa ejecución y abajo, en **Artifacts**, descarga **Sueno-ipa**. Es un .zip; adentro está `Sueno.ipa`.
3. Si sale un tache rojo, abre el paso que falló, copia las líneas que dicen `error:` y pégaselas a Claude para corregirlo.

## 3. Instalar SideStore (una sola vez)

1. En el iPhone, instala **LocalDevVPN** desde la App Store. SideStore la usa para instalar y renovar apps sin computadora.
2. En la computadora instala **iloader** desde su página oficial: https://github.com/nab138/iloader (o iloader.app). En Windows también necesitas **iTunes**.
3. Conecta el iPhone con cable, abre iloader, agrega tu Apple ID, elige tu iPhone y en instaladores elige **SideStore (Stable)**.
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos**, toca tu Apple ID y **Confiar**.
5. **Ajustes → Privacidad y seguridad → Modo de desarrollador**, actívalo y deja que se reinicie.
6. Abre **LocalDevVPN** y toca **Connect**.
7. Abre **SideStore → My Apps**, toca **7 DAYS** junto a SideStore e inicia sesión con el mismo Apple ID.

No instales Sueño dentro de LiveContainer: ahí no funcionan el widget ni los Atajos.

## 4. Instalar Sueño

1. Pasa `Sueno.ipa` al iPhone: por iCloud Drive o Google Drive, o mándatelo por Telegram o WhatsApp y usa **Guardar en Archivos**.
2. Con LocalDevVPN conectado, abre **SideStore → My Apps → +** y elige `Sueno.ipa`.
3. Si te pregunta por las extensiones, **consérvalas**: la extensión es el widget.
4. Abre Sueño y ve a **Ajustes → Diagnóstico**. Debe decir **Datos compartidos con el widget: Sí**.
5. Para el widget: mantén presionada la pantalla de inicio → **Editar → Añadir widget → Sueño**.

Con Apple ID gratis puedes tener hasta 3 apps instaladas así (SideStore cuenta como una) y registrar 10 identificadores de app por semana. Sueño usa 2: la app y el widget.

## 5. Renovación cada 7 días

SideStore renueva sola en segundo plano mientras LocalDevVPN esté conectado. Si alguna vez caduca, abre **SideStore → My Apps → Refresh All**. Tus datos no se borran.

## 6. Registrar tu sueño

Tienes cuatro formas; usa la que te acomode:

- **Detección automática**: al abrir la app, Sueño revisa el movimiento y los pasos del iPhone de las últimas 36 h y, si encuentra una noche sin registrar, te la propone en la pestaña Hoy. Tú decides si guardarla, editarla o descartarla. La primera vez pide permiso de **Movimiento y forma física**; no usa Salud.
- **Botones** en la pestaña Hoy: «Me voy a dormir» y «Ya me desperté».
- **A mano** en Historial con el botón +.
- **Desde la app Salud** con un Atajo (abajo). Es lo más automático si Salud ya tiene tu sueño (reloj, app de sueño u horario de sueño del iPhone).

Si importas un registro que se encima con otro, se queda el importado.

### Atajo «Importar sueño de Salud»

Los nombres pueden variar un poco según la versión de iOS; entre paréntesis va el nombre en inglés.

1. Abre **Atajos → +** y ponle de nombre «Importar sueño de Salud».
2. Agrega **Buscar muestras de salud** (Find Health Samples). Tipo: **Análisis del sueño**. Agrega el filtro **Fecha de inicio está en los últimos 14 días**. Ordena por fecha de inicio y deja el límite desactivado.
3. Agrega **Repetir con cada** (Repeat with Each) sobre esas muestras.
4. Dentro del bloque de repetir agrega **Texto** y arma esto:
   - la variable **Elemento de repetición**; tócala, elige **Fecha de inicio** y en formato de fecha elige **ISO 8601**;
   - escribe `|`;
   - otra vez **Elemento de repetición**, ahora **Fecha de finalización**, también en **ISO 8601**;
   - escribe `|`;
   - **Elemento de repetición** con la propiedad **Valor**.
5. Después de **Fin de repetir**, agrega **Combinar texto** (Combine Text): **Resultados de repetición** con **Nuevas líneas**.
6. Agrega la acción **Importar sueño** de la app Sueño y en Texto pon **Texto combinado**.
7. Córrelo una vez a mano y acepta el permiso para leer Salud.

Cada línea queda así: `2026-09-28T23:14:05-06:00|2026-09-29T06:58:12-06:00|Dormido`

### Automatizaciones

En **Atajos → Automatización → +**, eligiendo **Ejecutar inmediatamente**:

- **Alarma → Al detenerse**: ejecuta «Importar sueño de Salud». Así se importa sola tu noche cuando apagas la alarma.
- Si Salud no tiene tu sueño: **Enfoque Dormir → Al activarse**, acción «Me voy a dormir» de Sueño; y **Al desactivarse**, «Ya me desperté».

Usa una de las dos, no ambas, para no duplicar.

## 7. Actualizar la app

Cambias el código, lo subes a GitHub, descargas el nuevo `Sueno.ipa` y lo instalas encima con SideStore. Tus datos se conservan porque es la misma app. Por si acaso, antes usa **Ajustes → Exportar respaldo**.

## Si algo falla

- **Falla la compilación en GitHub:** copia las líneas con `error:` y pásaselas a Claude.
- **El widget dice «Abre Sueño»:** revisa Ajustes → Diagnóstico. Si dice «No», reinstala con SideStore conservando las extensiones. La app funciona igual aunque el widget no tenga datos.
- **No llegan los avisos:** Ajustes del iPhone → Notificaciones → Sueño.
- **No sale la noche detectada:** revisa Ajustes → Diagnóstico → Detección de sueño. Ahí ves si hay permiso, qué vio el sensor en las últimas 36 h y puedes correr las pruebas del detector.

## Cómo se calcula

Dentro de la app, **Ajustes → Cómo se calcula todo** trae todas las fórmulas. En corto:

- **Deuda:** Σ 14 · wᵢ · (necesidad − dormido) en 14 noches; anoche pesa 15 % y el resto baja 15 % por noche.
- **Necesidad:** tu valor manual, o con 21+ días de datos, promedio + 0.3 · (mediana de tus noches de rebote − promedio).
- **Curva:** modelo SAFTE con sus parámetros por defecto (reservorio de 2880 unidades que se vacía 30 por hora despierto, ritmo de 24 h + 12 h, inercia al despertar). La fase se ajusta a la mitad de tu sueño real y la deuda baja el reservorio.
- **Hora de dormir:** despertar − (necesidad + un poco para pagar deuda) − 15 min, nunca antes de tu ventana de melatonina.

Es una aproximación con el modelo público SAFTE; no es el algoritmo de RISE ni un dispositivo médico.
