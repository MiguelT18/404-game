# Arquitectura técnica

## Resumen

El mismo proyecto de Godot genera dos ejecutables:

- **Cliente (Windows):** lee entradas, las envía y muestra el estado.
- **Servidor de partida (Linux, headless):** simula toda la partida y es la única verdad.

```text
Cliente A --entradas--> Servidor de partida --estado--> Cliente A
Cliente B --entradas-->   (simulación)      --estado--> Cliente B
```

## Red

Se usa `ENetMultiplayerPeer`, con UDP y canales fiables y no fiables.

| Dato | Dirección | Entrega | Frecuencia |
|---|---|---|---|
| Entradas del jugador | Cliente a servidor | No fiable y ordenada | 30 Hz |
| Intentos de habilidad, compra o mejora | Cliente a servidor | Fiable | Al ocurrir |
| Instantáneas del estado | Servidor a cliente | No fiable y ordenada | 20 Hz |
| Eventos (muerte, torre destruida, fin) | Servidor a cliente | Fiable | Al ocurrir |

**Simulación:** el servidor avanza a 30 ticks por segundo en `_physics_process`, configurando `physics/common/physics_ticks_per_second = 30`. Cada entrada lleva un número de secuencia.

**Instantáneas:** usan RPC propios en vez de `MultiplayerSynchronizer`, porque minions, proyectiles y personajes deben viajar juntos y de forma compacta. Como 30 no es múltiplo de 20, se envían en 2 de cada 3 ticks; cada una lleva su tick, y la interpolación se guía por él.

**RPC:** todos viven en el autoload `Net` (`net/net.gd`), porque Godot exige la misma ruta de nodo en ambos lados. Servidor y cliente solo escuchan sus señales. El reenvío entre clientes (`server_relay`) está desactivado.

**Movimiento:** `Avatar` es un `CharacterBody3D` y usa `move_and_slide()` tanto en el servidor como al predecir. Debe ejecutarse dentro del tick de física, por eso la reconciliación ocurre en `_physics_process` y no en el RPC. Los personajes no chocan entre sí (capa 2, máscara 1), porque el cliente ve a los demás con retraso y la predicción no coincidiría. No hay gravedad: el suelo no tiene colisión y `motion_mode` es flotante.

**Suavizado en el cliente:**

- El personaje propio usa predicción: se mueve de inmediato y se corrige al llegar la instantánea, reaplicando las entradas aún no confirmadas.
- Las demás entidades se interpolan con unos 100 ms de retraso.
- La física va a 30 Hz, así que el personaje propio usa la interpolación de física de Godot para verse suave. Las entidades remotas la desactivan, porque se interpolan a mano.
- Solo se predice el movimiento. Daño, muertes y efectos de habilidades los confirma el servidor. El cliente puede mostrar la animación de lanzamiento al instante.

**Validación:** cada entrada se valida en el servidor. Las entradas inválidas se descartan. El cliente envía dirección y `yaw`, nunca posición ni velocidad, y el servidor consume una entrada por tick de una cola acotada, así que enviar más no da más velocidad. La conexión compara la versión del juego y rechaza clientes distintos.

**Fuera del MVP:** compensación de latencia en los impactos y filtrado de entidades por visibilidad.

## Carpetas

La estructura se crea a medida que cada hito la necesita.

```text
shared/   Reglas y simulación; se ejecutan en el servidor y, si hace falta, para predicción
client/   Cámara, entradas, interfaz, efectos y presentación
server/   Arranque del servidor, sesiones, validación y bucle de partida
net/      Protocolo: RPC, formato de entradas e instantáneas
data/     Recursos .tres: heroes/, abilities/, items/, modes/
maps/     Escenas de mapas
tests/    Pruebas automáticas
```

**Dependencias permitidas:** `client/` y `server/` pueden usar `shared/`, `net/` y `data/`. `shared/` no puede depender de `client/` ni de `server/`, ni usar nodos visuales, audio o interfaz. Por eso `shared/avatar.tscn` es solo el cuerpo, y el cliente le añade `client/avatar_visual.tscn`.

## Datos

Cada tipo de dato es una clase `Resource` con `class_name`. Agregar contenido debe consistir en crear un `.tres`, no en cambiar la lógica.

| Recurso | Campos principales |
|---|---|
| `HeroData` | Estadísticas base y por nivel, y 4 habilidades |
| `AbilityData` | Tipo, coste, cooldown, alcance, efectos y valores por nivel |
| `ItemData` | Precio y modificadores de estadísticas |
| `MatchModeData` | Jugadores por equipo, mapa, oro inicial y reglas como Regresar |

Las habilidades se componen de piezas reutilizables, como proyectil, área, desplazamiento, escudo y zona, para no programar cada una desde cero.

## Modos de partida

El servidor recibe el id del modo y carga su `MatchModeData`. Línea única 1v1 y partida completa 5v5 ejecutan el mismo código: solo cambian los datos y el mapa.

## Conexión antes de M6

El servidor se inicia a mano. Los jugadores escriben la IP y el puerto, y pueden usar Tailscale para no abrir puertos. La partida empieza cuando se conectan todos los jugadores que pide el modo.

Argumentos del servidor, leídos con `OS.get_cmdline_user_args()`:

| Argumento | Ejemplo | Uso |
|---|---|---|
| `--server` | | Arranca en modo servidor |
| `--port` | `7777` | Puerto de escucha |
| `--mode` | `line_1v1` | Id del modo |

## Matchmaking (M6)

Un proceso headless aparte, el **matchmaker**, mantiene una cola por modo.

1. El cliente se conecta al matchmaker y entra a la cola.
2. Con jugadores suficientes, el matchmaker reserva un puerto libre.
3. Arranca un servidor de partida con `OS.create_process()`, pasando puerto, modo y un token por jugador.
4. Envía a cada cliente la dirección y su token.
5. El servidor de partida rechaza conexiones sin un token válido.
6. Al terminar la partida, el proceso se cierra y el puerto queda libre.

## Pruebas

- **Reglas:** pruebas headless en `tests/run_tests.gd`, sin red ni interfaz, para daño, economía, cooldowns y condiciones de victoria. El modo `--script` no compila los autoloads, así que estas pruebas no pueden usar `Net` ni clases que dependan de él.
- **Red:** un servidor y dos clientes reales. `tests/net_smoke.sh` lo automatiza con clientes headless, que se lanzan como escena para tener autoloads. Desde M1 también se prueba entre redes distintas o simulando latencia y pérdida de paquetes.

## Exportación

| Plataforma | Uso | Resultado |
|---|---|---|
| Windows | Cliente | `.zip` con el `.exe` |
| Linux | Servidor | Ejecutable headless |

Los ajustes se guardan en `export_presets.cfg`, sin contraseñas ni claves. Cliente y servidor siempre deben salir de la misma versión.
