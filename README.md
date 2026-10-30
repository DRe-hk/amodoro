# Amodoro — Espacio Compartido en Pareja (Flutter + Next.js API + SQLite)

Aplicación móvil (**Flutter** para Android, preparada para iOS y Web) y servidor backend (**Next.js 16 + SQLite + Drizzle ORM**) desplegado en VPS de Azure (`http://68.211.73.23`).

## ✨ Características Principales

- **Barra Superior con Píldora Coral Uniforme (`#F08076` / `#D96B62`)**:
  - Navegación entre **`HOME`**, **`BOARDS`** y **`SETTINGS`** mediante toque o gesto *swipe* horizontal en tiempo real.
  - La píldora activa ocupa exactamente **`1/3` del ancho interno**, mantiene márgenes laterales para no tocar nunca el borde de la pantalla, tiene esquinas redondeadas (`rounded-full`) y altura vertical mínima (`22dp`).
- **Regla de Apodos Cruzados (`YO` vs Apodo)**:
  - Cada integrante de la pareja define el apodo del otro.
  - Tus propias tarjetas e ítems **siempre muestran `YO`** en tu pantalla.
  - En **`SETTINGS`** puedes ver qué apodo te puso tu pareja y editar el apodo que tú le das.
- **`HOME`**:
  - Tarjeta de bienvenida diaria de tu pareja en la parte superior con fecha en español (`LUNES · 12 DE OCTUBRE`), fondo pastel Material Design 3 y **contraste de texto automático**.
  - Soporta **foto/postal o dibujo arriba + texto abajo**, o **solo texto** (sin recuadro vacío arriba).
  - Reacciones con emojis y respuestas rápidas con textos predeterminados.
  - Historial deslizable de días anteriores + botones inferiores **`🕒 ENVIADOS`** y **`+ CREAR`** (con lienzo de dibujo interactivo a mano alzada).
- **`BOARDS` y Motor `DECIDIR`**:
  - Tableros compartidos: **`Actividades`** (unificado con Pendientes), **`Música`**, **`Pelis`** y tableros personalizados (`+`).
  - En **`Actividades`**, el primer espacio arriba a la izquierda del grid es el botón compacto **`DECIDIR`** con dos modos:
    1. **Ruleta**: elige 1 actividad al azar.
    2. **Votación secreta (4–5 actividades al azar)**: cada uno vota **Sí** o **No** sin mostrar resultados parciales; si hay empate, avanza automáticamente a una ronda de desempate hasta lograr una ganadora única.
- **Pantalla de Login**:
  - Acceso en 1 toque por perfil de pareja, usuario/contraseña (`drehk` / `pareja`, clave por defecto `amodoro2025`), o código de invitación de 8 caracteres (`K7M2-9QXP`).

## 🌐 Servidor VPS en Azure

- **URL activa**: `http://68.211.73.23`
- **Directorio en VPS**: `/home/azureuser/amodoro-server`
- **Proceso PM2**: `amodoro-server` (puerto interno `3050`, proxificado por Nginx `default_server` en puerto `80` sin afectar `drehk.dev` ni `alina.drehk.dev`).
