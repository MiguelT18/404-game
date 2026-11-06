# Hoja de ruta del MVP

**Hito actual: M0**

Actualiza esta línea al terminar cada hito. Un hito termina cuando se cumplen todos sus criterios de aceptación.

## Enfoque

El **MVP jugable es M3**: una partida 1v1 completa en línea única. Ese modo demuestra casi todo el juego, y los modos mayores reutilizan su mapa, reglas y red.

- La red se prueba desde M1, porque es el mayor riesgo técnico del proyecto.
- El arte es provisional, con cápsulas y formas simples, hasta M4.
- El matchmaking va al final. Hasta entonces, basta con conectarse por IP o Tailscale.

## Hitos

### M0: base verificada

- [ ] Cada integrante abre el proyecto en Godot 4.7 y lo ejecuta con F5.
- [ ] Cada integrante tiene su agente de IA leyendo `AGENTS.md`.

### M1: movimiento en red

- [ ] Existe un servidor headless y un cliente que se conecta por IP y puerto.
- [ ] Dos clientes se mueven y se ven en un mapa de prueba.
- [ ] La cámara en tercera persona funciona con mira central.
- [ ] El movimiento propio usa predicción y el de los demás se ve suave.
- [ ] Se probó entre dos redes distintas, o con latencia y pérdida de paquetes simuladas.

### M2: combate

- [ ] Un personaje (Guardián) tiene ataque básico y sus 4 habilidades.
- [ ] Cooldowns, maná, daño y muerte se calculan en el servidor.
- [ ] Un personaje muerto reaparece en su base.
- [ ] Hay interfaz básica de vida, maná y cooldowns.
- [ ] Las estadísticas se cargan desde recursos `.tres`.

### M3: MVP jugable, línea única 1v1

- [ ] El mapa de línea única tiene torres, núcleos y bases.
- [ ] Salen oleadas de minions que avanzan y pelean.
- [ ] Las torres atacan según su prioridad.
- [ ] Funcionan oro, experiencia, niveles y mejora de habilidades.
- [ ] La tienda de la base vende los 6 ítems y aplica sus efectos.
- [ ] Destruir el núcleo termina la partida y muestra al ganador.
- [ ] Dos personas juegan una partida completa en línea, de principio a fin, sin errores que la detengan.

### M4: segundo personaje y equipos

- [ ] Arcanista jugable, añadido con datos y piezas reutilizables.
- [ ] Hay una pantalla simple de elección de personaje.
- [ ] Los modos 2v2, 3v3, 4v4 y 5v5 funcionan en línea única.
- [ ] Existe un `.zip` para Windows y un servidor para Linux.
- [ ] Una partida 5v5 mantiene un rendimiento jugable.

### M5: partida completa

- [ ] El mapa de tres líneas tiene torres, oleadas y bases.
- [ ] Regresar a la base funciona.
- [ ] Se completa una partida 5v5 de principio a fin.

### M6: matchmaking

- [ ] Un jugador entra a la cola de un modo desde el menú.
- [ ] El matchmaker forma partidas y arranca servidores solo.
- [ ] Los servidores de partida rechazan conexiones sin token.
- [ ] Al terminar, el proceso se cierra y el puerto queda libre.

## Fuera del MVP

No implementes esto sin que el equipo lo pida:

- Cuentas, inicio de sesión y progresión entre partidas.
- Ranking y matchmaking por nivel de habilidad.
- Compras con dinero real y cosméticos.
- Reconexión a partidas en curso.
- Bots controlados por la computadora.
- Antitrampas avanzado.
- Compensación de latencia en los impactos.
- Jungla, monstruos neutrales y recetas de ítems.
- Instalador y actualizaciones automáticas.
