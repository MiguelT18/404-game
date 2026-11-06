# Guía para agentes de IA

Este archivo es el punto de entrada para cualquier agente que trabaje en el repositorio. Léelo antes de hacer cambios.

## El proyecto

"404" (nombre provisional) es un MOBA 3D en tiempo real con cámara en tercera persona, hecho con Godot 4.7 y GDScript. Dos equipos compiten por destruir el núcleo enemigo usando habilidades, ítems y recursos.

Los clientes son `.exe` para Windows. Las partidas corren en un servidor headless y autoritativo, creado con el mismo proyecto de Godot.

## Documentación

| Archivo | Cuándo leerlo |
|---|---|
| [docs/game-design.md](docs/game-design.md) | Reglas, modos, personajes, ítems y economía |
| [docs/architecture.md](docs/architecture.md) | Red, simulación, carpetas y datos |
| [docs/mvp-roadmap.md](docs/mvp-roadmap.md) | Hito actual, criterios de aceptación y lo que queda fuera |

Si estos documentos entran en conflicto, `docs/game-design.md` manda en reglas del juego y `docs/architecture.md` en decisiones técnicas. Señala el conflicto en vez de elegir en silencio.

## Reglas de trabajo

1. **Mantente en el hito actual.** Implementa solo lo que pide el hito marcado en `docs/mvp-roadmap.md`. No adelantes trabajo de hitos posteriores.
2. **El servidor decide.** Daño, oro, experiencia, cooldowns, compras y muertes se calculan en el servidor. El cliente solo envía intenciones y muestra el estado.
3. **Nunca confíes en el cliente.** El servidor valida cada entrada: alcance, cooldown, maná, oro, velocidad y si el personaje está vivo.
4. **Los datos van en recursos.** Las estadísticas de personajes, habilidades, ítems y modos viven en archivos `.tres` dentro de `data/`, no en el código.
5. **Un solo código para todos los modos.** No escribas ramas específicas para 1v1 o 5v5. Lo que cambia entre modos se define en su recurso de modo.
6. **Todo el contenido es original.** No uses nombres, personajes, arte, música, textos ni mapas de LoL, Dota 2, Smite u otros juegos. Inspirarse en las mecánicas del género está permitido.
7. **Mantén la documentación al día.** Si cambia una decisión de diseño o arquitectura, actualiza `docs/` en el mismo commit.
8. **Prueba la lógica nueva.** Las reglas de `shared/` llevan pruebas. Un cambio de red se prueba con servidor y dos clientes, no solo con uno.

## Godot

- Usa Godot 4.7 estándar y GDScript con tipado estático.
- Haz commit de los archivos `.uid`, porque guardan las referencias entre recursos.
- No hagas commit de `.godot/` ni de `build/`.
- Crea las escenas complejas en el editor. Editar `.tscn` a mano solo es adecuado para cambios pequeños.
- Los agentes no ven el editor: indica qué debe revisar una persona a ojo, como la cámara, las animaciones o la interfaz.

## Comandos

El ejecutable de Godot puede llamarse distinto en cada equipo; aquí aparece como `godot`.

```sh
# Ejecutar el cliente
godot --path .

# Importar recursos sin abrir el editor
godot --headless --path . --import
```

Si estos comandos cambian, actualízalos aquí.

```sh
# Ejecutar el servidor de partida
godot --headless --path . -- --server --port 7777 --mode line_1v1

# Ejecutar las pruebas de reglas
godot --headless --path . --script res://tests/run_tests.gd

# Ejecutar la prueba de red: un servidor y varios clientes headless
tests/net_smoke.sh
```

## Git

- Trabaja en una rama por tarea y une los cambios con un pull request.
- Haz commits pequeños, con mensajes en español que digan qué cambia.
- No subas secretos, direcciones de servidores privados ni claves de Tailscale.
