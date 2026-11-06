# Diseño del juego

Los valores numéricos son puntos de partida y se ajustarán jugando. La versión vigente de cada valor estará en los recursos de `data/`.

## Visión

Un MOBA de acción: el jugador controla directamente a su personaje desde atrás, apunta sus habilidades a mano y gana por puntería, posición y buenas decisiones económicas. Debe ser divertido para un grupo de amigos en partidas cortas.

**Pilares**

- **Habilidad directa:** los ataques y las habilidades se apuntan, y se pueden esquivar.
- **Decisiones constantes:** cada partida obliga a elegir entre pelear, conseguir oro o empujar la línea.
- **Partidas accesibles:** las reglas se entienden rápido y los modos pequeños duran poco.

## Bucle de partida

1. El jugador elige personaje y aparece en su base.
2. Compra ítems con el oro inicial y va a la línea.
3. Consigue oro y experiencia matando minions, enemigos y torres.
4. Sube de nivel, mejora habilidades y compra ítems.
5. Su equipo empuja, destruye las torres y luego el núcleo enemigo.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | W, A, S, D |
| Mover la cámara y apuntar | Ratón |
| Ataque básico | Clic izquierdo |
| Habilidades 1, 2 y 3 | Q, E, R |
| Habilidad definitiva | F |
| Abrir tienda (en la base) | P |
| Mejorar habilidad | Ctrl + tecla de la habilidad |

La cámara va detrás y sobre el hombro. Una mira fija en el centro de la pantalla marca hacia dónde apunta el personaje.

## Modos

| Modo | Equipos | Mapa | Hito |
|---|---|---|---|
| Línea única 1v1 | 1 contra 1 | Línea única | M3 |
| Línea única 2v2 a 5v5 | Hasta 5 contra 5 | Línea única | M4 |
| Partida completa 5v5 | 5 contra 5 | Tres líneas | M5 |

Los modos de línea única, parecidos al ARAM, son partidas rápidas en las que todos pelean en el mismo camino. La duración objetivo es de 10 a 15 minutos. Una partida completa apunta a entre 25 y 35 minutos.

El matchmaking (M6) permite entrar a una cola por modo. Antes de M6, los jugadores se conectan directamente al servidor.

## Mapas

**Línea única:** un camino recto entre las dos bases, con 2 torres por equipo y un núcleo en cada base. Los jugadores solo compran al estar en la base, es decir, al empezar o tras reaparecer.

**Tres líneas:** líneas superior, media e inferior, con 2 torres por línea y equipo, y un núcleo en cada base. La zona entre líneas es transitable y no tiene monstruos neutrales en el MVP. Aquí existe **Regresar**: canalizar durante 6 segundos para volver a la base, cancelable al recibir daño.

## Condición de victoria

Gana el equipo que destruye el núcleo enemigo. Las torres se destruyen en orden, desde la más alejada de la base, y el núcleo es invulnerable mientras quede en pie alguna torre de su línea. En el mapa de tres líneas basta con abrir una línea.

## Recursos

| Recurso | Uso | Cómo se obtiene |
|---|---|---|
| Vida | Al llegar a 0, el personaje muere | Regeneración lenta, base e ítems |
| Maná | Paga las habilidades | Regeneración lenta, base e ítems |
| Oro | Compra ítems | Ingreso pasivo y bajas |
| Experiencia | Sube de nivel | Estar cerca de bajas enemigas |

**Valores iniciales**

| Parámetro | Valor |
|---|---|
| Oro inicial | 600 |
| Oro pasivo | 2 por segundo |
| Oro por minion | 20 (solo quien da el golpe final) |
| Oro por matar a un personaje | 300 |
| Oro por torre | 150 para cada miembro del equipo |
| Nivel máximo | 15 |
| Tiempo de reaparición | 5 s + 2 s por nivel |

## Personajes

Cada personaje tiene ataque básico, 3 habilidades y una definitiva. Un punto de habilidad se gana por nivel, y la definitiva se desbloquea en el nivel 5.

Los nombres son provisionales. Estos dos personajes cubren los tipos de habilidad que el sistema debe soportar: proyectil, área, desplazamiento, mejora y zona persistente.

### Guardián (cuerpo a cuerpo, resistente)

| Tecla | Habilidad | Efecto |
|---|---|---|
| Q | Embestida | Corre hacia delante y daña a quien golpea |
| E | Golpe circular | Daña a los enemigos cercanos y los ralentiza |
| R | Baluarte | Obtiene un escudo temporal |
| F | Impacto | Salta a un punto y aturde al caer en un área |

### Arcanista (a distancia, daño alto, frágil)

| Tecla | Habilidad | Efecto |
|---|---|---|
| Q | Dardo | Proyectil recto de largo alcance |
| E | Campo gélido | Crea una zona que ralentiza y daña |
| R | Parpadeo | Se teletransporta una distancia corta |
| F | Descarga | Tras una breve carga, dispara un rayo que atraviesa enemigos |

## Ítems

Cada jugador lleva hasta 6 ítems. En el MVP, los ítems solo dan estadísticas y no hay recetas. Vender devuelve el 50 % del precio.

| Ítem | Precio | Efecto |
|---|---|---|
| Hoja afilada | 600 | Más daño físico |
| Foco arcano | 600 | Más poder de habilidad |
| Coraza | 600 | Más armadura |
| Corazón robusto | 800 | Más vida máxima |
| Cristal de maná | 500 | Más maná y regeneración de maná |
| Botas veloces | 400 | Más velocidad de movimiento |

## Minions

Cada 30 segundos, cada base envía por cada línea una oleada de 3 minions cuerpo a cuerpo y 2 a distancia. Avanzan por su línea y atacan lo primero que encuentran en su alcance. Si un personaje enemigo daña a un aliado cerca de ellos, pasan a atacarlo.

## Torres

Las torres atacan automáticamente a lo que entre en su alcance, con esta prioridad:

1. Un personaje enemigo que acaba de dañar a un personaje aliado.
2. Los minions enemigos.
3. Los personajes enemigos.

## Puntos abiertos

Estas decisiones aún no están tomadas. Pregunta al equipo en vez de asumirlas.

- Nombre definitivo del juego; "404" es provisional.
- Tema, ambientación y estilo visual.
- Monstruos neutrales y jungla tras el MVP.
- Selección de personajes en los modos de línea única: libre o al azar.
- Abandono de partida y comportamiento ante desconexiones.
