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
| Eventos (daño, efecto, muerte, torre destruida, fin) | Servidor a cliente | Fiable | Al ocurrir |

**Simulación:** el servidor avanza a 30 ticks por segundo en `_physics_process`, configurando `physics/common/physics_ticks_per_second = 30`. Cada entrada lleva un número de secuencia.

**Instantáneas:** usan RPC propios en vez de `MultiplayerSynchronizer`, porque minions, proyectiles y personajes deben viajar juntos y de forma compacta. Como 30 no es múltiplo de 20, se envían en 2 de cada 3 ticks; cada una lleva su tick, y la interpolación se guía por él. Llevan el estado de cada jugador, ordenado según `Net.State`, y una lista de entidades (muñecos, proyectiles y zonas), descrita en `Net.Entity`.

**RPC:** todos viven en el autoload `Net` (`net/net.gd`), porque Godot exige la misma ruta de nodo en ambos lados. Servidor y cliente solo escuchan sus señales. El reenvío entre clientes (`server_relay`) está desactivado.

**Movimiento:** `Avatar` es un `CharacterBody3D` y usa `move_and_slide()` tanto en el servidor como al predecir. Debe ejecutarse dentro del tick de física, por eso la reconciliación ocurre en `_physics_process` y no en el RPC. Los personajes no chocan entre sí (capa 2, máscara 1), porque el cliente ve a los demás con retraso y la predicción no coincidiría. El suelo no tiene colisión y `motion_mode` es flotante: la gravedad del salto se calcula en `MoveRules` y `Avatar` aterriza a mano en Y = 0. El cliente envía solo la intención de saltar con cada entrada, y el servidor decide. La instantánea incluye `move_factor` (0 si está aturdido, menos de 1 si está ralentizado) y la velocidad vertical, que el cliente aplica al predecir para no dar tirones.

**Habilidades:** el cliente envía `cast_ability(slot, aim)`, donde `aim` es el punto bajo la mira. La cámara va desplazada sobre el hombro, así que el `yaw` solo no apuntaría a la mira. El servidor guarda los lanzamientos en una cola acotada y los ejecuta en el tick de física, porque usan rayos contra los muros. Cada lanzamiento se valida (slot, `aim` finito, vivo, sin aturdir, maná y cooldown) y el punto se recorta al alcance. `AbilityRunner` ejecuta las piezas y `CombatState` guarda vida, maná y efectos de jugadores y muñecos. Los impactos usan geometría plana en `CombatRules`, sin físicas. El servidor avisa con el evento `CAST` cuando empieza un lanzamiento o su carga, y con `EFFECT` cuando se resuelve. Ambos llevan el id de quien lanza y el de la habilidad, igual que los proyectiles y zonas de la instantánea. El cliente busca ese id entre los héroes del modo y nunca carga una ruta recibida.

**Capas de colisión:** 1 muros, 2 personajes y 3 muñecos.

**Suavizado en el cliente:**

- El personaje propio usa predicción: se mueve de inmediato y se corrige al llegar la instantánea, reaplicando las entradas aún no confirmadas.
- Las demás entidades se interpolan con unos 100 ms de retraso.
- La física va a 30 Hz, así que el personaje propio usa la interpolación de física de Godot para verse suave. Las entidades remotas la desactivan, porque se interpolan a mano.
- Solo se predice el movimiento. Daño, muertes y efectos de habilidades los confirma el servidor. El cliente puede mostrar la animación de lanzamiento al instante.
- Los efectos de habilidades ajenas y los golpes esperan el mismo retraso de interpolación, para coincidir con donde se ve a cada uno.

**Validación:** cada entrada se valida en el servidor. Las entradas inválidas se descartan. El cliente envía dirección, `yaw` y si quiere saltar, nunca posición ni velocidad, y el servidor consume una entrada por tick de una cola acotada, así que enviar más no da más velocidad. La conexión compara la versión del juego y rechaza clientes distintos. El cliente envía el id de su héroe en `hello`; el servidor lo busca en `MatchModeData.heroes` y nunca carga una ruta recibida por la red.

**Fuera del MVP:** compensación de latencia en los impactos y filtrado de entidades por visibilidad.

## Carpetas

La estructura se crea a medida que cada hito la necesita.

```text
shared/   Reglas y simulación; se ejecutan en el servidor y, si hace falta, para predicción
client/   Cámara, entradas, interfaz, efectos y presentación
server/   Arranque del servidor, sesiones, validación y bucle de partida
net/      Protocolo: RPC, formato de entradas e instantáneas
data/     Recursos .tres: heroes/, abilities/, dummies/, items/, modes/
maps/     Escenas de mapas
models/   Modelos de Blender: heroes/, maps/
tests/    Pruebas automáticas
```

**Modelos:** cada modelo guarda su fuente `<id>.blend` y, junto a ella, el `<id>.glb` exportado desde Blender. Godot solo importa el `.glb`: la importación directa de `.blend` está desactivada en `project.godot`, porque exigiría tener Blender instalado en cada equipo y en el servidor headless. Los `.blend` y `.glb` se guardan con Git LFS (ver `.gitattributes`), y las copias `.blend1` no se suben. Godot extrae las texturas del `.glb` como `.png` junto a él; también van por LFS. Los modelos de héroes son solo presentación: los usa `client/heroes/<id>.tscn`, nunca `shared/` ni `server/`.

**Presupuesto de un héroe**, pensado para equipos de gama media y baja: unos 10.000 triángulos en total, un material para el cuerpo con texturas de 1024 px (color, rugosidad y normales) y un material de paleta pequeña para el arma. En el `.glb` el cuerpo es la malla `Body`, y el arma cuelga del empty `Weapon`, con su pivote en la mano y el empty `Tip` en la punta; así `client/heroes/<id>.tscn` solo instancia el `.glb`.

**Héroes con esqueleto:** un modelo puede traer `Skeleton3D` y un `AnimationPlayer` con los clips `idle`, `walk`, `run`, `run_back`, `jump` y `land`, más un clip por habilidad con el mismo nombre que su id (por ejemplo `arcanist_orb`). Entonces `HeroAnimator` crea un `HeroRig` (`client/hero_rig.gd`), un `AnimationTree` que elige el clip de movimiento a partir de cómo se desplaza el modelo, así que sirve igual para el jugador local y los remotos sin datos de red nuevos. Los hechizos animan solo de cintura para arriba si el héroe se mueve, y su velocidad se ajusta al cooldown o a la carga (`cast_delay`). Con esqueleto, Godot convierte `Weapon` y `Tip` en huesos, así que la escena añade un `BoneAttachment3D` llamado `Tip`; `HeroAnimator.tip()` lo busca a cualquier profundidad. En ese caso Godot 4.7 deja vacía la propiedad `skeleton` del cuerpo y la malla no se deforma, así que la escena la asigna (`skeleton = NodePath("..")`); las pruebas lo comprueban. Un modelo sin esqueleto sigue con los gestos por código. El Arcanista tiene rig y clips de Meshy; los clips de salto llegan sin la subida de la cadera, porque el salto lo hace el cuerpo físico. Si un modelo sale de un generador o de un escultor, se reduce en Blender y se hornean sus texturas del modelo alto al bajo, nunca se sube el modelo alto.

**Dependencias permitidas:** `client/` y `server/` pueden usar `shared/`, `net/` y `data/`. `shared/` no puede depender de `client/` ni de `server/`, ni usar nodos visuales, audio o interfaz. Por eso `shared/avatar.tscn` es solo el cuerpo, y el cliente le añade el modelo `client/heroes/<id>.tscn`, elegido por el id del héroe. Así el servidor no carga escenas visuales. Un héroe nuevo necesita su `.tres` y esa escena, con el frente hacia -Z y la base en Y = 0. La escena lleva un nodo `Weapon` con un `Tip` en la punta y, si tiene escudo, un `Shield`: `HeroAnimator` los mueve al lanzar cada pieza. Cada habilidad necesita un icono en `client/icons/<id>.svg`, elegido también por su id. Sus efectos los dibuja `CombatVisuals` según su pieza (`AbilityData.Kind`), con partículas, luces y shaders hechos en código en `client/fx/`, así que no necesitan arte propio; `fx_color` cambia su color. El retrato de la interfaz se renderiza una vez desde el modelo, y el minimapa se genera del nodo `Floor` y de los `StaticBody3D` del mapa, así que no necesitan imágenes propias.

## Datos

Cada tipo de dato es una clase `Resource` con `class_name`. Agregar contenido debe consistir en crear un `.tres`, no en cambiar la lógica.

| Recurso | Campos principales |
|---|---|
| `HeroData` | Tipo de ataque y de daño, estadísticas base y por nivel, ataque básico y 4 habilidades |
| `AbilityData` | Pieza, tipo de daño, coste, cooldown, alcance, efectos, valores por nivel y color de sus efectos |
| `DummyData` | Vida, resistencias y tiempo de reinicio de un muñeco de práctica |
| `ItemData` | Precio y modificadores de estadísticas |
| `MatchModeData` | Jugadores por equipo, mapa, héroes disponibles, oro inicial y reglas como Regresar |

Las habilidades se componen de piezas reutilizables (`AbilityData.Kind`) para no programar cada una desde cero: cono, proyectil, área, desplazamiento, escudo, zona, teletransporte, salto y rayo. Cualquiera puede tener una carga previa con `cast_delay`.

## Modos de partida

El servidor recibe el id del modo y carga su `MatchModeData`. Línea única 1v1 y partida completa 5v5 ejecutan el mismo código: solo cambian los datos y el mapa.

## Conexión antes de M6

El servidor se inicia a mano. Los jugadores escriben la IP y el puerto, y pueden usar Tailscale para no abrir puertos. La partida empieza cuando se conectan todos los jugadores que pide el modo.

Para probar en un solo equipo, el botón **Practicar en local** del menú arranca un servidor de `hero_test` en el puerto 7777 y se conecta. Un segundo jugador pulsa lo mismo: su servidor no puede abrir el puerto, se cierra solo y entra a la partida existente. El menú sigue visible hasta entrar, y el cliente se rinde a los 8 s si nadie responde.

Argumentos del servidor, leídos con `OS.get_cmdline_user_args()`:

| Argumento | Ejemplo | Uso |
|---|---|---|
| `--server` | | Arranca en modo servidor |
| `--port` | `7777` | Puerto de escucha |
| `--mode` | `line_1v1` | Id del modo |
| `--quit-when-empty` | | Cierra el servidor tras 10 s seguidos sin jugadores |

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
