# FootballLegacy H — Documentación completa del juego

> Documento de referencia del proyecto: qué es, cómo está armado, qué trae hoy
> y qué falta. Si algo acá no coincide con el código, **manda el código**.
>
> Última actualización: 3 de noviembre de 2026 · Versión 0.9.0 · Esquema de guardado v35

---

## Índice

1. [Ficha técnica](#1-ficha-técnica)
2. [Concepto y pilares](#2-concepto-y-pilares)
3. [Flujo de juego](#3-flujo-de-juego)
4. [Arquitectura del proyecto](#4-arquitectura-del-proyecto)
5. [Sistemas de carrera](#5-sistemas-de-carrera)
6. [El partido 3D](#6-el-partido-3d)
7. [El partido por decisiones (2D)](#7-el-partido-por-decisiones-2d)
8. [Arte y audio](#8-arte-y-audio)
9. [Persistencia y guardado](#9-persistencia-y-guardado)
10. [Ajustes y preferencias](#10-ajustes-y-preferencias)
11. [Exportación, validación e instalación](#11-exportación-validación-e-instalación)
12. [Mejoras implementadas en esta ronda](#12-mejoras-implementadas-en-esta-ronda)
13. [Mejoras pendientes (priorizadas)](#13-mejoras-pendientes-priorizadas)
14. [Limitaciones conocidas](#14-limitaciones-conocidas)
15. [Checklist de pruebas en el teléfono](#15-checklist-de-pruebas-en-el-teléfono)

---

## 1. Ficha técnica

| Dato | Valor |
|---|---|
| Nombre | **FootballLegacy H** (variante horizontal) |
| Versión | 0.9.0 (`version/code=1`) |
| Motor | **Godot 4.7.2 stable** · GDScript |
| Plataforma objetivo | Android (móvil), con build de escritorio para depurar |
| Orientación | Horizontal fija (`handheld/orientation=4`) |
| Resolución base | **1024 × 576**, estirado `canvas_items`, aspecto `expand` |
| Paquete Android | `com.wilber.footballlegacy.h` |
| APK de depuración | `build/FootballLegacy_H.apk` (~82,3 MB) |
| Firma | Automática al exportar; verificado v2/v3 |
| Tipo de juego | Carrera **individual** de futbolista (no se dirige un club) |
| Modo de partido | 3D jugable si sos titular · partido por decisiones si no |
| Persistencia | 3 slots · JSON · esquema **v35** |
| Estado | Beta jugable (0.9.0) |
| Idioma | Español |
| Repositorio | Sin control de versiones (no es repo Git) |

**Escalera de arranque real:** `res://scenes/Start/Start.tscn` → creación de
personaje → prueba → ofertas → Hub de carrera.

---

## 2. Concepto y pilares

El juego es una **carrera personal**: creás un futbolista de 16 años, elegís
origen, posición, pie hábil y dificultad de progresión, y vivís su carrera
completa desde el barrio hasta el retiro. No manejás un club: manejás **una
vida**.

**Pilares de diseño**

1. **Un solo protagonista.** Todo gira alrededor del jugador: contratos,
   relaciones, prensa, família, plata, lesiones, capitanía, legado.
2. **Mundo vivo y determinista.** 55 ligas, 928 clubes y 199 países generados
   desde una semilla. Los mismos datos producen siempre el mismo mundo; el
   resto del campeonato se simula solo aunque no lo estés mirando.
3. **Partido con consecuencias.** El 3D no es un adorno: las jugadas, los
   goles, las faltas y las notas del partido alimentan estadísticas,
   reputación, confianza del DT y progresión.
4. **Ritmo configurable.** El partido se puede jugar **Detallado**, **Normal**
   o **Rápido**; la carrera se puede avanzar por día, semana, mes o hasta el
   próximo partido.
5. **Todo se explica.** Cada sistema tiene su motor puro (sin UI) y su
   pantalla; la matemática vive en un solo lugar.

---

## 3. Flujo de juego

### 3.1 Arranque de una carrera

```
Start
 └─ Selección de slot (3)
     └─ CharacterCreation
         ├─ Test de personalidad (20 preguntas)
         ├─ Nombre, país, posición, pie, origen, dificultad
         └─ AvatarCreator (cara, pelo, cuerpo, kit)
             └─ Partido de prueba (MatchLauncher → partido 3D/decisiones)
                 └─ 5 ofertas de club (CareerSetup)
                     └─ Firma de contrato (ContractDecision / WageOffer)
                         └─ Hub
```

- **Origen** modifica el arranque narrativo y los atributos iniciales
  (barrio humilde, cantera de club grande, etc.).
- **Dificultad de progresión** (`easy` / `normal` / `hard`) escala la velocidad
  con la que suben los atributos y el overall.
- El **test de personalidad** define rasgos de personalidad (ambición,
  lealtad, etc.) que después usan la prensa, los entrenadores y las ofertas.

### 3.2 El Hub (día a día)

Desde el Hub se accede a todo. El avance del tiempo pasa **siempre** por
`WorldTickEngine.advance_day()`, que actualiza el mundo entero (resultados de
las otras ligas, mercado, noticias, lesiones, sanciones, contratos).

| Área | Pantallas |
|---|---|
| Partido | `PreMatch`, `Match`, `Match3D`, `MatchSummary`, `PostMatchInterview`, `NationalMatchSummary` |
| Carrera | `Hub`, `Calendar`, `Standings`, `CupBracket`, `Planner`, `Training`, `Squad` |
| Mercado | `Offers`, `Transfers`, `PlayerSearch`, `WageOffer`, `ContractDecision`, `Loan` (dentro de Transfers) |
| Vida | `Lifestyle`, `Social`, `Shop`, `Coleccion`, `Sponsors`, `SponsorOffer`, `Agent`, `Investment` (en Lifestyle) |
| Club | `ClubInfo`, `Selections`, `NationalCallUp`, `Awards`, `SeasonCeremony`, `SeasonEvent`, `Retirement` |
| Mundo | `WorldExplorer`, `ImportWorld`, `News`, `PlayerProfile`, `Settings` |

### 3.3 Un día de partido

```
Hub → PreMatch (previa, rival, táctica, balón, clima)
     → Match3D (si sos titular) o Match (si vas al banco)
         → MatchSummary (marcador, notas, estadísticas)
             → PostMatchInterview (si el partido fue destacado)
                 → Hub (con el día ya avanzado)
```

### 3.4 Cierre de temporada

Al terminar la última fecha: `WorldTickEngine` hace el **rollover** →
clasificaciones finales, ascensos/descensos, premios, Balón de Oro, Bota de
Oro, renovaciones, mercado, y `SeasonCeremony` + `Awards` muestran el
resultado. Si el jugador se retira, `LegacyEngine` dispara la ceremonia de
despedida y la retirada de camiseta.

---

## 4. Arquitectura del proyecto

### 4.1 Carpetas

```
FootballLegacy_H/
├─ project.godot              Configuración del proyecto y autoloads
├─ export_presets.cfg         Preset Android (firma incluida)
├─ autoloads/                 Singletons globales
├─ data/                      Resources y catálogos (PlayerData, Kit, Trophy…)
├─ engine/                    Lógica pura del juego (sin UI)
│   ├─ world/                 Generación y simulación del mundo
│   ├─ match/                 Motor de partido por decisiones
│   ├─ match/m3d/             Puente entre carrera y partido 3D
│   └─ career/                Todos los sistemas de carrera
├─ scenes/                    43 pantallas (.tscn + .gd)
├─ match3d/                   Partido 3D (escena, scripts, modelos)
├─ match_live/                Partido 2D "en vivo" por gestos (estacionado)
├─ ui/common/                 Componentes reutilizables de UI
├─ assets/                    Arte, audio, fuentes, iconos
├─ tools/                     Sondas de validación y scripts de arte
├─ build/                     APK exportado
└─ docs de trabajo            README.md, ROADMAP.md, CLAUDE.md, este archivo
```

### 4.2 Autoloads (singletons)

| Autoload | Rol |
|---|---|
| `SaveManager` | Persistencia de los 3 slots, migraciones de esquema (v1 → v35), carga/guardado |
| `WorldTickEngine` | **Única** fuente de avance de día; cachea mundo y temporada; rollover |
| `MatchState` | Estado compartido entre PreMatch → Partido → Resumen → Entrevista |
| `Preferences` | Ajustes globales de la app (moneda, ritmo, cámara, sonido, texto…) |
| `Audio` | Música con crossfade, SFX de UI y de partido, ambiente con *ducking* |
| `CharacterDraft` | Borrador de creación/edición de avatar entre pantallas |
| `Nav` | Navegación y transiciones entre escenas |
| `Haptics` | Vibración en Android/iOS |

### 4.3 Reglas de arquitectura (heredadas de Football Legacy)

- **Una sola fuente de tiempo.** Ninguna pantalla duplica el avance de día.
- **El motor de partido no sabe de UI.** `MatchEngine` produce eventos;
  la UI solo los dibuja.
- **La matemática no se dispersa.** `DecisionResolver`, `CoachRelations`,
  `PlayerDevelopment`, `ContractEngine`, etc. concentran sus fórmulas.
- **Todo campo nuevo persistido = cambio de esquema + migración.**
- **El mundo se deriva de la semilla.** Lo que no se persiste se reconstruye
  igual cada vez.

### 4.4 Capas y responsabilidades

| Capa | Ejemplos | Responsabilidad |
|---|---|---|
| Datos | `PlayerData`, `ClubData`, `LeagueData`, `Kit`, `Trophy`, `Traits`, `Positions` | Estructura y catálogos |
| Mundo | `WorldFactory`, `WorldImporter`, `SeasonEngine`, `LeagueTable`, `SeasonCalendar` | Generar y simular el mundo |
| Carrera | 70+ motores en `engine/career/` | Contratos, prensa, vida, progresión |
| Partido | `MatchEngine`, `MatchSimulator`, `DecisionResolver`, `Match3DBridge` | Simular y resolver jugadas |
| Presentación | `scenes/`, `match3d/`, `match_live/`, `ui/common/` | Pantallas y 3D |
| Herramientas | `tools/*probe.gd`, `tools/*.py` | Validación y arte |

---

## 5. Sistemas de carrera

### 5.1 Mundo y competiciones

| Motor | Qué hace |
|---|---|
| `WorldFactory` | Genera el mundo determinista: **55 ligas**, **928 clubes**, **199 países**, plantillas bajo demanda, entrenadores y fuerzas |
| `WorldImporter` | Construye un mundo a partir de un JSON externo (modo importar mundo) |
| `WorldTickEngine` | Avanza el día, simula el resto del mundo, rollover de temporada |
| `SeasonCalendar` | Calendario determinista: liga (método del círculo) + cuadro de copa |
| `SeasonEngine` | Resultados de la temporada para todo el mundo; mantiene el "mundo vivo" |
| `LeagueTable` | Clasificación de cualquier liga hasta el día actual |
| `TopPerformersEngine` | Tabla de goleadores y asistentes por liga o copa |
| `CoefficientEngine` | Coeficiente de cada liga según cómo le fue a sus clubes en copas continentales |
| `PromotionRelegationEngine` | Ascensos y descensos entre categorías del mismo país |
| `ContinentalEngine` | Copa continental de clubes (UEFA, CONMEBOL, CONCACAF, CAF, AFC) |
| `NationalCupEngine` | Copa continental de selecciones (Eurocopa, Copa América, Copa Oro…) |
| `WorldCupEngine` | Mundial de selecciones, formato real 2026+ (48 equipos, 12 grupos) |
| `ClubWorldCupEngine` | Mundial de Clubes jugable (32 clubes, 8 grupos) |
| `SuperCupEngine` | Supercopas de una sola fecha y Mundial de Clubes cada 4 años |
| `QualifyingEngine` | Eliminatorias al Mundial por confederación |
| `NationalTeamFactory` | Fuerza de cada selección (no existía en el generador de clubes) |
| `RivalryEngine` | Clásicos y derbis entre clubes, con efecto en el ambiente |
| `DisciplineEngine` | Tarjetas, suspensiones y lesiones en los partidos de toda la liga |
| `Formations` | Formaciones y estilo de juego deterministas por club |
| `CalendarUtils` | Temporada ago–may sin cortes por año calendario |
| `BallonDorEngine` | Ranking del Balón de Oro (goles + asistencias ponderados por liga) |

### 5.2 Jugador y progresión

| Sistema | Qué hace |
|---|---|
| `PlayerData` | Ficha completa: identidad, 10 atributos, stats, contrato, lesiones, rasgos, avatar, finanzas |
| `PlayerDevelopment` | Toda la matemática de subida de atributos y duración de lesiones |
| `ProgressionEngine` | Nivel de carrera, XP, puntos de habilidad y **forma** (v33) |
| `CareerRpgEngine` | Capa RPG ampliada (vida, vínculos, decisiones, percepciones) |
| `TraitEngine` | Desbloquea **38 rasgos** por hitos de carrera |
| `SkillTree` | Árbol de habilidades con puntos |
| `Positions` | Posiciones finas (POR, DFC, MCO, DC…) y compatibilidades |
| `Nickname` | Apodo determinista que pone la prensa al ganar peso |
| `HonorsEngine` | Detecta títulos y honores de la temporada para el gabinete |
| `ClubHonorsEngine` | Palmarés histórico derivado del club (no se persiste) |
| `LegacyEngine` | Retiro: ceremonia, retirada de camiseta, legado |
| `CaptaincyEngine` | Capitanía ganada por tiempo, relación y reputación |
| `MatchRatingCalculator` | Nota del partido a partir de **eventos reales** |
| `DecisionResolver` | Atributos + rival + precisión del input → éxito/fallo |

### 5.3 Club, contratos y dinero

| Sistema | Qué hace |
|---|---|
| `ContractEngine` | Salario, ingresos y renovación |
| `NegotiationEngine` | Regateo con el presidente, estado puro que consume la UI |
| `WageOfferEngine` | Renegociación de sueldo a mitad de contrato (llega sola) |
| `TransferOfferEngine` | Ofertas de otros clubes en cualquier momento de la temporada |
| `TransferRequestEngine` | El jugador pide salir; presidente y DT responden |
| `TransferMarketEngine` | Mercado IA ↔ IA con presupuesto y valor de mercado reales |
| `LoanEngine` | Cesiones pedidas por el jugador, con elección de club |
| `AgentEngine` | Representante generado una vez; calidad 1–5 estrellas |
| `BootDealEngine` | Patrocinio de guayos (4 marcas), con guayos regalados |
| `SponsorEngine` | Ofertas de patrocinio como estado persistente |
| `PrizeMoneyEngine` | Primas por título al cierre de temporada |
| `StaffEngine` | Staff personal con bono pasivo semanal |
| `InvestmentEngine` | Inversiones que se resuelven solas al vencer |
| `ShopEngine` | Tienda de consumibles entre partidos |

### 5.4 Vida, prensa y relaciones

| Sistema | Qué hace |
|---|---|
| `LifestyleEngine` | Vivienda y coche del jugador |
| `SocialLifeEngine` | Salidas (cine, pareja, ver partidos), vida fuera del fútbol |
| `RelationshipEngine` | Vida familiar y pareja con efecto en el bienestar |
| `PlannerEngine` | Planificador semanal: una actividad por semana ISO |
| `WeeklyGoalsEngine` | 3 objetivos semanales deterministas con recompensa |
| `ObjectivesEngine` | Objetivos de temporada |
| `SeasonEventEngine` | 0–3 eventos inesperados por temporada (buenos o malos) |
| `SeasonReportEngine` | Resumen de fin de temporada con nota 0–10 |
| `ImmersionEngine` | Vestuario post-partido, comentarios de compañeros, detalles |
| `InterviewEngine` | Entrevista de opción múltiple tras partidos destacados |
| `PressGenerator` | Titulares de prensa adaptados al partido del jugador |
| `RivalMindGamesEngine` | Frase del DT rival antes y reacción después |
| `CoachRelations` | Toda la confianza jugador–entrenador |
| `CoachChangeEngine` | Destitución del DT a mitad de temporada |
| `CoachChallengeEngine` | Reto del DT antes de cada partido oficial |
| `SocialEngine` | Red social tipo Twitter, feed determinista |
| `WorldPulseEngine` | Red social "Mundo": clubes, jugadores y selecciones |
| `WorldNewsEngine` | Titulares del mundo (líderes, goleadores, fichajes) |
| `ScoutingEngine` | Informe del rival para la previa |

### 5.5 Lanzadores y soporte de partido

| Sistema | Qué hace |
|---|---|
| `MatchLauncher` | Arma los dos `MatchTeam` de un fixture y deja el partido en `MatchState` |
| `NationalTeamMatchLauncher` | Lo mismo para partidos de selección |
| `MatchTeam` | Representación genérica de un equipo en un partido |
| `MatchEvent` | Evento emitido por el motor; lo consumen UI y animaciones |
| `MatchSimulator` | Simulación estadística instantánea de partidos IA |
| `MatchEngine` | Corazón del partido por decisiones; se detiene en tus momentos |
| `Match3DBridge` | Configura, lanza y recoge el resultado del partido 3D |

---

## 6. El partido 3D

Archivo principal: `match3d/scripts/match.gd` (clase `SoccerMatch`).

### 6.1 Cancha y equipos

- Cancha reglamentaria **105 × 68 m**.
- Arcos algo más anchos que el reglamentario (7,32 × 2,44) para que se marque
  mejor en móvil.
- El **equipo 0 es el local y es el tuyo**; ataca hacia **+X**.
- Tu jugador lleva la marca **"Tú"**.
- Se aplican planteles reales del partido (`_apply_rosters`), kits con decals
  (`_bake_kit_decals`), nombres y dorsales.

### 6.2 Máquina de estados

```
SIMULATING → MOMENT_INTRO → MOMENT → MOMENT_RESULT → (siguiente)
SIMULATING → AMBIENT_GOAL → CELEBRATION → SIMULATING
           → REPLAY → SIMULATING
           → WALKOUT → (partido) → LOCKER (entretiempo) → …
           → OUTRO → MVP_CEREMONY
           → PENALTY_SHOOTOUT (si hace falta)
           → CUTSCENE (banco / cambio)
           → ENDED
```

### 6.3 Momentos clave

El partido se simula solo (minutos, comentarios, ambiente) y se detiene cuando
tu jugador está involucrado. Las jugadas dependen de tu posición:

| Momento | Cuándo aparece |
|---|---|
| `ATTACK` | Ataque armado con pelota en tus pies |
| `COUNTER` | Contraataque rápido |
| `CROSS` | Centro desde banda |
| `CORNER` | Tiro de esquina |
| `FREE_KICK` | Tiro libre |
| `PENALTY` | Penal |
| `BUILDUP` | Construir y dar el pase clave (mediocampo) |
| `DEFENSE` | Defender tu arco |
| `KEEPER` | Atajada (si sos arquero) |

### 6.4 Controles

- **Tocar** para pasar / moverte / elegir opción.
- **Multitoque al césped** para esprintar a un punto: dos o tres toques seguidos
  en la misma zona aumentan la velocidad y gastan más estamina.
- **Deslizar** para chutar (dirección y potencia).
- **Gesto con dos dedos** para zoom en la cancha (según pantalla).
- Como arquero: deslizar para volar y elegir altura.
- En la tanda de penaltis: gesto de tiro con stats normales + decisión de palo.

### 6.5 Cámara

- En las acciones del jugador la cámara va **siempre detrás de él** (anclada a
  su `facing`), más cerca que antes: **2,9 m detrás**, **3,3 m de altura**,
  **0,5 m lateral**.
- En los momentos de definición se acerca y encuadra el arco.
- En las celebraciones busca al goleador de frente.
- `_update_camera()` + `_update_occlusion()` evitan que el cuerpo tape la
  jugada.

### 6.6 IA (`ai_brain.gd`)

- IA por reglas: cada frame decide hacia dónde moverse y, con un pequeño
  retraso, si chutar, pasar o entrar.
- **Defensa:** cooldown de entrada de **1,5 s**, probabilidad escalada (no
  tackles en bucle), marcaje pegado dentro del área, cobertura del hueco y
  presión coordinada.
- **Ataque:** apoyo en espacio libre, llegada del segundo mediocentro al área
  (`_late_run`), centros desde banda y desmarques.
- **Portero:** sale a balones altos dentro de su área y achica.
- **Rendimiento:** `closest_to_point_cached()` e `intercept_point_cached()`
  cachean por frame para no recorrer todos los jugadores varias veces.

### 6.7 Faltas, penaltis y tiros libres

- Si la falta ocurre **dentro del área** → **penal**.
- Si ocurre **fuera** → **tiro libre desde el lugar exacto** de la falta.
- El árbitro cobra con `_call_foul()`; la barrera y la posición se arman
  alrededor del balón.
- En el penal, el arquero elige palo y altura; el remate usa la precisión y la
  altura calculadas con stamina.

### 6.8 Goles, no-goles y goles fantasma

- Existen **goles ambientales** narrados (`_start_ambient_goal`) y **ocasiones
  falladas** (`_start_ambient_miss`) para que el partido no sea solo tus
  jugadas.
- Los goles narrados usan `shoot_exact` para que el balón **entre a la vista**.
- **Gol fantasma eliminado:** si el balón no entra, la ocasión termina en
  "¡NO ENTRA!" y **no** se toca el marcador.
- Variedad: pase previo opcional, remates distintos, porteros que responden
  distinto.

### 6.9 Celebraciones

- `CELEB_RUN_MAX = 5.5 s`: el goleador corre al **banderín**.
- `CELEB_DANCE = 6.0 s` (y `CELEB_DANCE_AMBIENT = 4.5 s`): celebra de frente a
  la cámara.
- La cámara de celebración (`_celebration_camera`) sigue al goleador y después
  vuelve al juego.
- Con `reduce_motion` activo las celebraciones se acortan.

### 6.10 Túnel, vestuario y despedida

- **WALKOUT:** salida del túnel con cámara lateral, paso calibrado
  (`WALK_LINE_PAN = 5.5`), movimiento reducido (`move_input *= 0.45`) y chorros
  de humo (`_tunnel_jets`).
- **LOCKER:** charla del entrenador en el entretiempo, con opciones y bebida
  isotónica (`_use_halftime_drink`).
- **OUTRO:** despedida tras el pitido final, con movimiento reducido
  (`move_input *= 0.4`).
- **CUTSCENE:** plano del banco y de tu cambio (el reloj no corre).

### 6.11 Suplentes, estamina y cambios

- **Barra de estamina** visible durante el partido.
- Botones **"Pedir entrar"** y **"Pedir salir"**: el técnico decide.
- Si el técnico acepta, se produce una **sustitución real**: entra un jugador
  del banquillo y **cambia el avatar** en cancha (`_swap_in_star`,
  `_enter_from_bench`).
- La estamina afecta precisión y altura del remate.
- El **multitoque** al moverte gasta estamina extra: correr más rápido tiene
  precio y por debajo de un mínimo ya no hay sprint.
- El **cansancio se ve**: zancada más corta, respiración agitada e inclinación
  extra al correr.

### 6.12 Ritmo del partido

`Preferences.match_pace_factor()`:

| Ritmo | Factor | Efecto |
|---|---|---|
| Detallado | **1.6** | Partido más largo, más momentos y narración |
| Normal | **1.0** | Equilibrio por defecto |
| Rápido | **0.55** | Partido corto, menos pausas |

Se conecta directamente con el reloj del partido 3D y con `MatchEngine`.

### 6.13 Repetición

- `replay_director.gd` graba a **30 Hz** (`REC_HZ`).
- La reproducción respeta esa frecuencia (sin acelerones ni saltos).
- `_start_replay()` / `end_replay()` / `_back_to_simulation()` gestionan la
  vuelta al partido.

### 6.14 Tanda de penaltis

- Se arma una secuencia de tiradores (`_build_shootout_sequence`).
- El **ganador se decide por el marcador real** de la tanda; si sigue empatada,
  **muerte súbita**.
- Tu penalti se ejecuta con gesto + stats normales.
- **No hay rebote:** tu remate no abre una segunda jugada y los de la IA se
  detienen en la línea si no son gol.
- `_roll_shootout_outcome` mantiene el `keeper_skill()` original del arquero.

### 6.15 Global de ida y vuelta

- `Match3DBridge.build_config()` lee el global de `fixture.tie_agg`, con
  fallback a `eng._tie_carry`.
- El `tie_agg` de la vuelta se guarda como `{"home": goles_ida_local,
  "away": goles_ida_visitante}` y el puente lo mapea a `carry_us` /
  `carry_them` según `user_home`, para que una ida 3–2 **nunca** se muestre
  como 0–0 en la vuelta.
- `_has_return_leg()`, `_aggregate_score()`, `_aggregate_tied()`,
  `_needs_extra_time()` y `_needs_shootout()` resuelven prórroga y tanda.

### 6.16 Rendimiento y FPS

- **Resolución 3D adaptativa** (`_setup_render_quality`, `_adapt_render_scale`):
  escala entre **0.65 y 1.0** según FPS reales, con objetivo **50–58 fps**.
- **MSAA 2X** solo en PC; desactivado en móvil.
- **Glow** solo de noche.
- **Sombras** limitadas a 45 m.
- **HUD** actualizado a 10 Hz (no cada frame).
- **Ola del público** solo al cambiar de estado, no por frame.

### 6.17 Estadísticas del partido

- `ball.last_kick_kind` y `ball.sot_counted` identifican el tipo de remate y
  evitan contar dos veces el mismo tiro a puerta.
- `_count_sot()` cuenta un tiro a puerta **una sola vez por remate**.
- `on_shot()` suma remates en todos los estados.
- Los cabezazos usan `kind = "shot"` y `on_shot(p)` para **ambos equipos**.
- `reset_to()` limpia tipo y contador al reiniciar.
- Invariante de validación: **`on_target ≤ shots`** siempre.

---

## 7. El partido por decisiones (2D)

Carpeta `match_live/`: es el partido "en vivo" por gestos sobre una cancha 2D,
**estacionado** por decisión del autor (la jugabilidad táctil no convenció en
el teléfono). El partido por defecto es **por decisiones** (`live_play = false`
y se ignora lo guardado).

| Archivo | Rol |
|---|---|
| `match.gd` | Escena y flujo del partido en vivo |
| `live_bridge.gd` | Puente con `MatchEngine` |
| `field.gd`, `goal.gd`, `stadium.gd` | Cancha, arcos y estadio 2D |
| `ball.gd`, `player.gd` | Física simple y jugador |
| `player_sprite.gd`, `sprites.gd`, `pitch_avatar.gd` | Sprites y avatares |
| `pitch_formations.gd`, `team.gd` | Formaciones y equipos |
| `pitch_referee.gd` | Árbitro en cancha |
| `scenarios.gd` | Jugadas guionadas |
| `cfg.gd`, `hud.gd`, `names.gd`, `score_styles.gd`, `sfx.gd` | Configuración, HUD, nombres, marcador y sonido |

El modo `live_play` sigue en Ajustes como código, pero **apagado** y sin opción
visible.

---

## 8. Arte y audio

### 8.1 Volumen de assets

| Carpeta | Archivos | Contenido |
|---|---:|---|
| `assets/pixelplayer` | 5 796 | Jugadores pixel art (8 direcciones, animaciones) |
| `assets/ui` | 2 725 | Marcos, botones, iconos, fondos |
| `assets/flags` | 1 397 | Banderas de países |
| `assets/characters` | 905 | Piezas de avatar |
| `assets/icons` | 861 | Iconos de juego |
| `assets/referee` | 392 | Árbitro y jueces de línea |
| `assets/playercreator` | 374 | Piezas del creador |
| `assets/icons` (px/s) | 68 | Iconos chicos |
| `assets/trophies` | 266 | Trofeos 3D renderizados |
| `assets/kits` | 238 | Camisetas |
| `assets/complogos` | 188 | Escudos de competición |
| `assets/medals` | 143 | Medallas y honores |
| `assets/crests` | 140 | Escudos de club |
| `assets/audio` | 129 | Música, UI, ambiente, SFX |
| `assets/stadium` | 132 | Estadio |
| `assets/balls` | 92 | Balones |
| `assets/brands` | 36 | Marcas |
| `assets/coach` | 36 | Entrenadores |
| `assets/sound` | 30 | Sonidos reales de partido |
| `assets/sfx` | 28 | Efectos |
| `assets/events` | 24 | Ilustraciones de eventos |
| `assets/scoreboards` | 18 | Marcadores |

### 8.2 Catálogos de contenido

- **55 ligas**, **928 clubes**, **199 países**.
- **16 balones** (`BallDesign.DESIGNS`): Clásico, Estrella, Flúor, etc.
- **~32 diseños de kit** (`KitTemplates`).
- **38 rasgos** de jugador (`Traits.CATALOG`), con modificadores concretos
  (`finish`, `set_piece`, `penalty`, `playmk`, `defense`, `fatigue_factor`,
  `rep_factor`).
- **35+ trofeos/honores** (`Trophy`), con arte propio o fallback procedural.

### 8.3 Arte procedural

Todo lo que no tiene arte propio se genera por código y queda **determinista**:

- `Crest.gd` — escudos de club.
- `Kit.gd` / `kit_decals.gd` — camisetas y decals.
- `Trophy.gd` / `trophy_builder.gd` — trofeos.
- `field_builder.gd` — cancha 3D.
- `hair_builder.gd`, `player_avatar.gd`, `arm_pose.gd` — avatares y brazos.
- `stadium_staff.gd`, `referee.gd` — personal de estadio.
- `award_gala.gd`, `trophy_ceremony.gd`, `mvp_ceremony.gd`, `locker_room.gd`,
  `trophy_room.gd` — escenas 3D de ceremonia.

### 8.4 Audio (`autoloads/Audio.gd`)

- **UI:** `.ogg` de Kenney.
- **Partido:** sonidos reales en `assets/sound/*.mp3` (silbato, gol, tarjetas,
  lesión) con **fallback** a los `.wav` procedurales de `assets/audio/match/`.
- **Música:** `game_music_1..5.mp3`, encadenadas al azar con crossfade y bucle
  infinito.
- **Ambiente:** `crowd_ambience.mp3` en loop, con **ducking** cuando suena un
  evento del partido para que el efecto resalte.

---

## 9. Persistencia y guardado

### 9.1 Formato

- Directorio: `user://saves/`.
- **3 slots** independientes.
- Archivo JSON con forma:

```json
{
  "schema_version": 35,
  "player": { "...PlayerData..." },
  "world_seed": 123456,
  "season": { "...calendario y estado de temporada..." },
  "market_salt": 98765
}
```

- `SaveManager` valida la versión al cargar: si no coincide, intenta migrar; si
  falta la migración, avisa por `push_warning` y no rompe el archivo.
- **Escritura atómica (v35, P0-12):** se escribe `<slot>.json.tmp`, el principal
  sano se rota a `<slot>.json.bak` y recién entonces el temporal pasa a ser el
  principal. Si el `.json` queda truncado o desaparece, `load_slot()` recupera
  desde `.bak` o `.tmp` y lo reescribe como principal.
- **Autoguardado:** pausa de la app, cierre de ventana y botón atrás de Android
  vuelcan `WorldTickEngine.season`; cada cambio de pantalla hace lo mismo con
  throttle de 1,5 s (ver `SaveManager.autosave` y `Nav._process`).

### 9.2 Historial de esquema (resumen)

| Versión | Cambio |
|---|---|
| v1 | `{ schema_version, player }` |
| v2 | `world_seed` |
| v3 | `season` (calendario de liga y copa) |
| v4 | `player.detailed_position` |
| v5 | confianza del entrenador |
| v6–v12 | relaciones, objetivos, vida, finanzas, sponsors, lesiones |
| v13–v20 | selecciones, trayectoria, títulos, contratos, mercado |
| v21 | `player.traits` (rasgos) |
| v22 | cosméticos y desbloqueos |
| v23 | `player.attribute_xp` |
| v24 | `market_salt` (mercado distinto por carrera) |
| v25 | `player.growth_difficulty` |
| v26–v31 | nivel/XP, forma, vida social, staff, inversiones |
| v32 | `player.boot_deal` (patrocinio de guayos) |
| v33 | RPG ampliado y vida fuera del fútbol |
| v34 | ajustes de selecciones y copas |
| **v35** | esquema actual |

> Regla: **todo campo nuevo persistido exige anuncio explícito + migración
> real**. Este documento y el código deben actualizarse juntos.

### 9.3 Qué NO se persiste

- El estado del partido en curso (`MatchState` es de un solo uso).
- El borrador de creación (`CharacterDraft`).
- Todo lo derivado del mundo: clasificaciones, palmarés de clubes, fuerza de
  selecciones, noticias, feed social, apodos, scouting.
- Las preferencias globales (van en `user://preferences.json`).

---

## 10. Ajustes y preferencias

`autoloads/Preferences.gd` guarda en `user://preferences.json`, **fuera** del
save de la carrera (no dispara migraciones).

| Ajuste | Valores | Efecto |
|---|---|---|
| Moneda | EUR / USD | Visualización de dinero |
| Balón | fijo / aleatorio | Balón del próximo partido |
| Último balón | índice | Solo si el modo es fijo |
| Ritmo de partido | Detallado / Normal / Rápido | `1.6 / 1.0 / 0.55` |
| Confirmar avance | sí / no | Pide confirmación al avanzar días |
| Reducir movimiento | sí / no | Menos público, confeti y celebraciones |
| Sonido de hinchada | sí / no | Ambiente del partido |
| Escala de texto | normal / grande | `content_scale_factor` 1.0 / 1.12 |
| Cámara de cancha | arco | Fija en "arco" (las otras se ignoran) |
| Partido 3D | sí / no | 3D si sos titular; apagado = decisiones |
| Partido en vivo | apagado | Código estacionado, sin opción visible |
| Tutorial visto | sí / no | Ya viste los controles |

---

## 11. Exportación, validación e instalación

### 11.1 Herramientas

| Herramienta | Ruta |
|---|---|
| Godot (consola) | `C:\Users\USUARIO\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |
| Proyecto | `C:\Users\USUARIO\Desktop\Proyectos\Godot\FootballLegacy_H` |
| ADB | `C:\Users\USUARIO\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Teléfono de prueba | Samsung S24 — `RFCY916KJGB` (SM-S921B) |
| APK | `build/FootballLegacy_H.apk` |

### 11.2 Compilar y validar

```powershell
# Chequeo de compilación (headless)
& "C:\Users\USUARIO\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --headless --path . --quit

# Sonda de gameplay 3D (tarda varios minutos)
& "..." --headless --path . res://tools/M3DGameProbe.tscn
```

Resultado esperado de la sonda: **`PROBE OK (0 fallos)`** y la invariante
`on_target ≤ shots`.

### 11.3 Exportar

```powershell
& "..." --headless --path . --export-debug "Android" "build/FootballLegacy_H.apk"
```

- El preset ya incluye firma; la exportación **firma y verifica** el APK
  automáticamente con `apksigner` (build-tools 36.0.0).
- Verificación manual disponible en `build-tools\36.1.0\apksigner.bat`.
- Comprobar siempre que `export_presets.cfg` quede con
  **`package/signed=true`** después de cada exportación.

### 11.4 Instalar en el teléfono

```powershell
& "C:\Users\USUARIO\AppData\Local\Android\Sdk\platform-tools\adb.exe" `
  -s RFCY916KJGB install -r build\FootballLegacy_H.apk
```

---

## 12. Mejoras implementadas en esta ronda

Ronda centrada en **IA, animaciones, fluidez, cámara, jugadas y FPS** para el
proyecto horizontal.

### 12.1 Cámara

- [x] Cámara **siempre detrás** del jugador, anclada a su `facing`.
- [x] Más cerca: **2,9 m** detrás, **3,3 m** de altura, **0,5 m** lateral.
- [x] Encuadre de definición que se acerca al arco.
- [x] Cámara de celebración que busca al goleador de frente.
- [x] Oclusión corregida para que el cuerpo no tape la jugada.

### 12.2 IA

- [x] **Cooldown de tackle** de 1,5 s.
- [x] Probabilidad de entrada **escalada** (se acabaron los tackles en bucle).
- [x] **Marcaje pegado** dentro del área.
- [x] **Cobertura del hueco** y presión coordinada.
- [x] **Apoyo en espacio libre** para el compañero.
- [x] Llegada del **segundo mediocentro** al área (`_late_run`).
- [x] **Centros desde banda**.
- [x] **Portero** que sale a balones altos en su área.
- [x] Caché por frame de `closest_to_point_cached()` e
  `intercept_point_cached()`.

### 12.3 Animaciones

- [x] Blend de animaciones más corto y estable (**0.08–0.12 s**).
- [x] Mirada al balón reducida al sprintar.
- [x] Giro más suave.
- [x] **Cansancio visible**: zancada corta, respiración agitada, inclinación
  extra.

### 12.4 Faltas y jugadas

- [x] Falta dentro del área → **penal**.
- [x] Falta fuera del área → **tiro libre desde el lugar exacto**.
- [x] Cabezazos: **solo el más cercano**, con balón bajando y **0.9 s** de
  pausa (se acabaron los cabezazos en cadena).
- [x] **Gol fantasma eliminado**: si el balón no entra, no hay marcador.
- [x] **Variedad de goles y no-goles** (`_start_ambient_miss`, pase previo
  opcional, remates y porteros variados).
- [x] Jugadas de gol narradas con `shoot_exact` para que el balón entre a la
  vista.

### 12.5 Celebraciones y túnel

- [x] Celebraciones más largas: `CELEB_RUN_MAX = 5.5`, `CELEB_DANCE = 6.0`,
  `CELEB_DANCE_AMBIENT = 4.5`.
- [x] El goleador **corre al banderín** y celebra **de frente a la cámara**.
- [x] Túnel más calmado: `WALK_LINE_PAN = 5.5`, `move_input *= 0.45` en walkout
  y `0.4` en outro.

### 12.6 Pases y control

- [x] `ball.trap` más fuerte (**0.12**).
- [x] Umbral de recepción bajado a **5,5 m/s** (se acaban los pases que se
  escapan).
- [x] Pase con dirección y potencia más legibles.

### 12.7 Tanda de penaltis

- [x] Penalti del usuario con **gesto + stats normales**.
- [x] **Sin rebote**: el remate no abre segunda jugada.
- [x] Los penales de la IA se **detienen en la línea** si no son gol.
- [x] Ganador por **marcador real** y **muerte súbita** si sigue empatada.
- [x] `_roll_shootout_outcome` mantiene el `keeper_skill()` original.

### 12.8 Global de ida y vuelta

- [x] `Match3DBridge.build_config()` lee `fixture.tie_agg` con fallback a
  `eng._tie_carry`.
- [x] Una ida 3–2 **ya no** se muestra como 0–0 en la vuelta.
- [x] Prórroga y tanda se disparan solo si el global sigue empatado.

### 12.9 Estadísticas

- [x] `ball.last_kick_kind` / `ball.sot_counted` para no contar dos veces.
- [x] `_count_sot()` en goles, paradas y estiradas.
- [x] Eliminado el doble conteo de `_finish_moment`.
- [x] `on_shot()` suma remates en todos los estados.
- [x] Cabezazos con `kind = "shot"` y `on_shot(p)` para ambos equipos.
- [x] `reset_to()` limpia tipo y contador.
- [x] Validado `on_target ≤ shots`.

### 12.10 Estamina y cambios

- [x] **Barra de estamina** visible.
- [x] Botones **"Pedir entrar"** y **"Pedir salir"** con decisión del técnico.
- [x] **Sustitución real** con jugador del banquillo.
- [x] **Cambio visual del avatar** al entrar.
- [x] La estamina afecta precisión y altura del remate.

### 12.11 Rendimiento

- [x] **Resolución 3D adaptativa** (0.65–1.0) según FPS, objetivo 50–58.
- [x] **MSAA 2X** solo en PC; apagado en móvil.
- [x] **Glow** solo de noche.
- [x] **Sombras** a 45 m.
- [x] **HUD** a 10 Hz.
- [x] **Ola del público** solo al cambiar de estado.
- [x] Repetición grabada a **30 Hz** (`REC_HZ`) y reproducida a esa frecuencia.

### 12.12 Ritmo y consistencia RPG

- [x] Ritmo **Detallado / Normal / Rápido** conectado al partido 3D.
- [x] Precisión y altura de tiro afectadas por stamina.
- [x] `overall()` consistente con las 6 stats principales y clamp **20–99**.
- [x] Validación headless limpia y APK exportado, firmado y verificado.

---

## 13. Mejoras pendientes (priorizadas)

**Leyenda**

| Código | Significado |
|---|---|
| **P0** | Bloqueante, bug visible o decisión que hay que tomar antes de seguir |
| **P1** | Se nota en cada partido; cambia la sensación del juego |
| **P2** | Pulido, contenido y profundidad; se puede posponer |
| **ID** | Referencia estable para anotar avances y hablar de un ítem concreto |

Los ítems marcados con **✔ criterio** incluyen una forma rápida de saber si
quedaron bien.

---

### 13.1 P0 — Bloqueantes y decisiones

- [x] **P0-01 · VAR real o cosmético confeso.** Decidir si el VAR anula goles;
      si sigue siendo decorativo, sacarlo del HUD para no prometer algo que no
      hace. ✔ criterio: un gol anulado por VAR no mueve el marcador y se ve la
      repetición del motivo.
      *Verificado:* el VAR es real. `DecisionResolver.var_review` decide revisión
      y anulación con el multiplicador del árbitro; `MatchEngine` emite
      `GOAL_DISALLOWED` y no toca el marcador; la UI y `PitchPlays.var_mode`
      muestran la repetición del motivo. Sonda: `tools/VarRefereeProbe.tscn`
      (160 partidos: 389 goles, 11 anulados, `score_goals == goal_events`).
- [x] **P0-02 · Árbitro con personalidad.** Perfiles `estricto`, `equilibrado`
      y `permisivo`, por árbitro y por competición: más o menos amarillas,
      tolerancia a protestas y criterio en el área. ✔ criterio: dos partidos
      con árbitros distintos se sienten distintos sin mirar la camiseta.
      *Verificado:* `DecisionResolver.referee_profile` deriva el perfil del
      nombre del árbitro (`Venue.referee`, semilla por competición) y aplica
      `card_mult`, `var_mult`, tolerancia a protestas y criterio de área.
      Sonda: `VarRefereeProbe` — 5 personalidades y tarjetas
      tarjetero 1064 > neutro 671 > permisivo 455.
- [x] **P0-03 · Faltas a favor.** Que la IA te derribe y nazca tiro libre o
      penal de la jugada, no solo de guion. ✔ criterio: aparece un penal a
      favor sin guion al menos una vez cada varios partidos.
      *Hecho:* `engine/match/FoulResolver.gd` (área real `x ≥ 36`, `|z| ≤ 20,15`),
      riesgo de falta por lectura/sangre fría + árbitro, falta a favor cuenta
      como jugada buena y la sonda `tools/M3DFoulProbe.tscn` valida penalti,
      tiro libre y no doble conteo.
- [x] **P0-04 · Global ida/vuelta en TODAS las competiciones.** Verificar copa
      nacional, copa continental, selecciones y Mundial de Clubes, no solo
      liga. ✔ criterio: cualquier eliminatoria de dos legs muestra el global
      correcto en la vuelta.
      *Auditado:* copa nacional y continental usan ida/vuelta con `tie_agg`
      (`has_tie_carry`, `carry_us/carry_them`) y muestran el global en HUD y
      resultado; el Mundial de Clubes y el Mundial de selecciones son a partido
      único por formato, así que no llevan global. Sin cambios de código.
- [x] **P0-05 · Tanda sin rebote en todos los caminos.** Cubrir usuario, IA,
      muerte súbita, arquero y fallo de palo. ✔ criterio: 20 tandas seguidas
      sin que se abra una segunda jugada.
      *Hecho:* el penalti del usuario cierra la jugada con el primer desenlace
      (gol, parada, rechace, palo o fuera); se congela al tirador y se ignoran
      toques/gestos posteriores. El gol de la tanda ya no mueve el marcador ni
      las estadísticas del partido. La secuencia siempre juega las 5 tandas por
      equipo y la muerte súbita añade pares hasta desempatar. Sonda:
      `tools/M3DShootoutProbe.tscn` (20 tandas, 0 fallos).
- [ ] **P0-06 · Probar en el teléfono todo lo de esta ronda.** Checklist de la
      sección 15 y anotar cada fallo con captura.
- [x] **P0-07 · Cancha "Ver todo" ovalada.** Revisar la perspectiva simétrica
      con Wilber y corregir proyección o encuadre.
      *Auditado:* ya estaba corregido. `PitchView.TILT_FAR = 1.0` elimina el
      factor de profundidad que estrechaba la cancha lejana y deformaba el
      óvalo; la proyección vuelve a ser lineal y simétrica. Falta solo la
      confirmación visual en el teléfono (dentro de P0-06).
- [x] **P0-08 · Nombres ilegibles con cámara alejada.** Escalar el texto por
      distancia o apagarlo a partir de cierta distancia.
      *Auditado:* ya estaba corregido. `PitchView._draw_labels` calcula el
      tamaño de fuente como `11 / cam_zoom` (acotado a 11–26) para que el
      nombre mida igual en pantalla al alejar, y con `cam_zoom < 0.5` deja solo
      el nombre del usuario para no llenar la vista de rótulos.
- [x] **P0-09 · Física de la pelota.** Pique, efecto y comba: que el balón
      pique antes de entrar, se desvíe en un defensor y doble en un tiro libre.
      *Hecho:* el bote ya usa el material físico del balón (rebote 0.5), el
      efecto (`curl_rate`) dobla tiros y tiros libres, y un remate fuerte
      (>13 m/s) que llega a un defensor de campo ahora rebota en su cuerpo con
      `ball.deflect_body()` en vez de quedar limpio a sus pies. Sonda:
      `M3DRulesProbe` (remate a 20 m/s desviado y atribuido al defensor).
      También se corrigió el falso "balón parado": un chute recién lanzado
      conserva su velocidad en `_pending_velocity` hasta el siguiente paso de
      física y ahora `ball.speed()` la tiene en cuenta, así el remate del pase
      clave ya no se cierra antes de cruzar la línea.
- [x] **P0-10 · Repetición de la tanda.** Cancha propia para rever la tanda
      (hoy no existe).
      *Hecho:* la tanda 3D entera se graba con `ReplayDirector` (la condición de
      grabación incluye `State.PENALTY_SHOOTOUT` y `_start_penalty_shootout`
      reinicia el buffer). Al decidirse el ganador se muestra el botón de
      repetición durante 6 s; al pulsarlo se abre la cancha de repetición con
      cámara libre y, al cerrarla, `_resume_shootout_after_replay` devuelve el
      estado a la fase "winner" (con el botón para reverla otra vez) en vez de
      saltar al final de la jugada. `_update_camera` no pelea con la cámara
      libre mientras `state == REPLAY`. Sonda: `M3DShootoutProbe`
      (graba, reproduce, vuelve al ganador y deja el botón visible).
- [x] **P0-11 · Transiciones de animación.** Eliminar el "patinaje" entre idle,
      carrera, giro, remate y frenada.
      *Hecho:* `SoccerPlayer` mezcla la locomoción según el cambio de velocidad y
      la vuelta desde una acción (`locomotion_blend`), con histéresis en los
      umbrales idle/walk/run. El giro usa `_turn_toward` (velocidad angular
      progresiva) y `turn_speed_factor` frena el cuerpo al encarar otra
      dirección. Sonda: `tools/M3DMotionProbe.tscn`.
- [x] **P0-12 · Autoguardado a prueba de cierres.** Guardar al salir de un
      partido y al cambiar de pantalla crítica; nunca perder una jornada.
      *Hecho:* escritura atómica `.tmp` → rotación `.bak` → rename en
      `SaveManager.save_slot`, recuperación automática en `load_slot`,
      `autosave()` en pausa/cierre/atrás y en cada cambio de pantalla
      (`Nav._process`), y `delete_slot` limpia las tres copias. Sonda:
      `tools/SaveAutosaveProbe.tscn`.
- [x] **P0-13 · Auditoría de goles fantasma.** Repasar remate normal, cabezazo,
      gol ambiental y rebote: ningún camino debe mover el marcador sin que el
      balón entre.
      *Hecho:* el pase clave ya no regala el gol. El receptor remata de verdad
      (`ball.kick(..., "shot")`), el tanto solo cuenta al cruzar la línea en
      `_on_goal_area_entered` y el remate guionizado no puede interceptarse en
      vuelo. `_finish_moment` evita el doble cierre. Sonda:
      `tools/M3DRulesProbe.tscn`.
- [x] **P0-14 · Auditoría de doble conteo.** Revisar tiros, tiros a puerta,
      paradas y asistencias en todos los estados (`on_shot`, `_count_sot`,
      `_finish_moment`) para que `on_target ≤ shots` se cumpla siempre.
      *Auditado:* `on_shot` cuenta el remate una vez y `_count_sot` usa
      `ball.sot_counted` para no repetir; el gol y la parada ya no suman dos
      veces. Los penaltis de la tanda no entran en las estadísticas del partido.
      Sin cambios de código salvo el caso de la tanda (P0-05).
- [x] **P0-15 · Balón dividido y pases fuertes.** Que un pase a 6–8 m/s se
      pueda controlar con el cuerpo, no solo con el pie.
      *Hecho:* `ball.trap_body` permite el control con pecho/muslo a media altura
      (0,95–1,65 m) hasta 9 m/s, con primer toque más suelto que el pie; por
      encima de 9 m/s el balón sigue pasando. El cabezazo ya no se come esos
      balones. Sonda: `M3DRulesProbe` (7 m/s se controla, 12 m/s no).
- [x] **P0-16 · Sustituciones limpias.** Verificar que al entrar/salir no queden
      dos avatares, colisiones duplicadas ni el jugador sin control.
      *Auditado:* `_sub_off_star` y `_enter_from_bench` reutilizan el mismo nodo
      `SoccerPlayer`, restauran nombre/perfil y conservan las colisiones; no hay
      avatares duplicados. Sonda: `M3DRulesProbe`.

---

### 13.2 P1 — Partido 3D: control, jugadas y definición

- [x] **P1-01 · Remate con potencia.** Mantener para cargar y soltar; la barra
      de potencia visible y ligada a la stamina.
      *Hecho:* la potencia suma el largo del deslizamiento y el tiempo mantenido
      (`CHARGE_FULL_SECONDS` 0,7 s), con techo de stamina
      (`SHOT_STAMINA_MIN_CAP` 0,55 → 1,0). El HUD muestra la barra en vivo con
      marca blanca del techo (`MatchHUD.show_power`). Sonda:
      `tools/M3DChargeProbe.tscn`.
- [x] **P1-02 · Efecto en el remate.** Deslizar al cargar para abrir el balón
      al segundo palo.
      *Hecho:* la curva del gesto (`bend`) se multiplica por el techo de efecto
      de la stamina (`SHOT_STAMINA_MIN_CURL` 0,45 → 1,0), así que al 85' hay
      que elegir entre colocar o golpear. Misma sonda que P1-01.
- [x] **P1-03 · Zona de tiro visible.** Un arco de puntería que se achica con
      la distancia, la fatiga y la presión del rival.
      *Hecho:* `engine/match/m3d/ShotZone.gd` (puro) calcula el radio de la zona
      segura en metros: máximo a quemarropa y fresco, mínimo lejos, agotado y con
      un rival encima. El partido proyecta ese radio sobre el arco y el HUD lo
      dibuja como un aro (`MatchHUD.show_aim_zone`) que pasa de verde a rojo al
      achicarse; solo aparece cuando hay un remate posible y se apaga al cerrar
      la jugada. Sonda: `tools/M3DShotZoneProbe.tscn`.
- [x] **P1-04 · Asistencia de puntería configurable.** Tres niveles (alta,
      media, manual) para que el juego sea accesible sin quitar skill.
      *Hecho:* `Preferences.aim_assist` (global, `user://preferences.json`, no
      toca el save de carrera) con niveles `alta`/`media`/`manual` (por defecto
      `media`). `ShotZone.assist_dir` mezcla la dirección del gesto con la
      dirección al arco (0,55 / 0,28 / 0,0) y el partido lo aplica solo al
      remate (`_shot_dir_assist`), no a los pases ni a los regates; el aro de
      P1-03 usa la misma dirección corregida. Se elige en Ajustes → Juego →
      «Asistencia de puntería». Sonda: `tools/M3DShotZoneProbe.tscn`.
- [x] **P1-05 · Regate con combos.** Dos o tres gestos encadenados que superen
      al defensor según su atributo de defensa.
      *Hecho:* `engine/match/m3d/DribbleCombo.gd` (puro) define la ventana de
      0,9 s, el ángulo mínimo de 35° para que el quiebro cuente y el bonus de
      +0,12 por eslabón (máx. 3). La chance de superar al rival usa el
      `dribbling` tuyo contra `duel_skill(true)` del defensor (fuerza + lectura
      + velocidad) y el portero resiste más; el mareo crece con el combo
      (0,9 → 1,4 s). El partido corta el combo al pasar, rematar, perder el
      balón o cambiar de jugador. Sonda: `tools/M3DDribbleComboProbe.tscn`.
- [x] **P1-06 · Jugadas de lujo.** Rabona, sombrero, elástica y bicicleta como
      gestos de alto riesgo y alta recompensa.
      *Hecho:* `engine/match/m3d/SkillMove.gd` (puro) clasifica el dibujo del
      gesto: círculo → bicicleta, V → elástica, arco tendido → sombrero, curva
      de un lado → rabona. El éxito usa regate/control/pase contra la fuerza
      defensiva del rival y cada jugada cuesta stamina (0,04–0,07) y abre 1,1 s
      de enfriamiento. La elástica marea 1,2 s, la bicicleta 0,7 s, el sombrero
      pica la pelota por encima del defensor y la rabona la manda con efecto al
      compañero libre; si fallan, te dejan expuesto o la pelota queda corta.
      Sonda: `tools/M3DSkillMoveProbe.tscn`.
- [x] **P1-07 · Pase al hueco dibujado.** Arrastrar hacia dónde cae la pelota,
      no solo hacia quién.
      *Hecho:* en el armado, el deslizamiento manda la pelota al punto del campo
      que dibujaste con el dedo (`SoccerPlayer.pass_to_point`, con la misma
      compensación de aire que el centro para que caiga ahí) y el compañero más
      cercano a ese punto es el que corre a recibirla (`_nearest_teammate_to`);
      los rivales también pueden cortarla. El pase ya no se cuenta como remate.
      Sonda: `tools/M3DThroughPassProbe.tscn`.
- [x] **P1-08 · Pase de primera.** Tocar antes de que llegue el balón para
      jugar a un toque.
      *Hecho:* si el balón viene hacia ti (a menos de 3,4 m, por debajo de 1,3 m
      y a más de 2,5 m/s), el toque lo juega de primera sin controlarlo:
      `SoccerPlayer.first_touch_pass` golpea desde donde está el balón, lo manda
      al compañero tocado o al hueco dibujado y te bloquea un instante para no
      recogerlo en el acto. Tocar cerca de ti sigue siendo moverse, y con el
      balón controlado, lejos, lento o alejándose no se activa. Sonda:
      `tools/M3DFirstTouchProbe.tscn`.
- [x] **P1-09 · Pase bombeado.** Mantener el pase para levantarla por encima
      del defensor.
      *Hecho:* mantener el toque sobre un compañero 0,45 s o más ejecuta
      `SoccerPlayer.lofted_pass`: `engine/match/m3d/LoftedPass.gd` (puro)
      calcula la velocidad vertical para que el balón pase medio metro por
      encima de un defensor, el tiempo de caída con el frenado del aire y la
      velocidad horizontal para dejarla en los pies del compañero. Un toque
      corto sigue siendo un pase raso. Sonda: `tools/M3DLoftedPassProbe.tscn`.
- [x] **P1-10 · Centro con zona elegida.** Elegir primer palo, segundo palo o
      punto de penal antes de centrar.
      *Hecho:* `engine/match/m3d/CrossZone.gd` (puro) calcula los tres puntos
      del área y la altura del centro. En el momento de centro el lateral espera
      tu elección; el HUD muestra tres botones (1ER PALO · 2º PALO · PUNTO
      PENAL), tu jugador ataca la zona elegida y `SoccerPlayer.cross_to_point`
      lanza el balón a esa altura. Si no eliges en 2,2 s, sale solo al primer
      palo. Sonda: `tools/M3DCrossZoneProbe.tscn`.
- [x] **P1-11 · Cabezazo con timing.** Salto y contacto medidos; el más cercano
      sigue teniendo prioridad, pero ahora se puede fallar por llegar tarde.
      *Hecho:* `engine/match/m3d/HeaderTiming.gd` (puro) define la franja de
      cabeza (1,55–1,98 m), la altura ideal y el alcance según fuerza y temple.
      El partido solo cabecea con el balón bajando dentro de la franja, da
      prioridad al más cercano y, si llega tarde o lejos, el testazo no sale o
      sale flojo y desviado. Sonda: `tools/M3DHeaderTimingProbe.tscn`.
- [x] **P1-12 · Jugadas encadenadas.** Un buen regate abre remate, un buen pase
      abre asistencia; la jugada no muere en el primer gesto.
      *Hecho:* `engine/match/m3d/PlayChain.gd` (puro) calcula la ventana y el
      bonus del remate que nace de un regate (más potencia y puntería, y se
      apaga en 2,2 s) y la ventana de asistencia tras un pase (2,6–4,2 s según
      `passing`). Si el receptor define dentro de la ventana, cuenta el pase
      clave y su remate sale algo más fuerte. Sonda:
      `tools/M3DPlayChainProbe.tscn`.
- [x] **P1-13 · Elegir antes de la jugada.** Conducir, pasar rápido o aguantar
      antes de que arranque la animación.
      *Hecho:* `engine/match/m3d/PrePlayChoice.gd` (puro) define las tres
      elecciones, el destino de conducción, la puntuación del pase y el alivio
      del aguante. En la intro de las jugadas de ataque con balón aparecen tres
      botones (CONDUCIR, PASE RÁPIDO, AGUANTAR); la elección se aplica al
      arrancar la jugada: conducir fija un sprint corto hacia la portería, pasar
      suelta el balón al compañero mejor colocado (y abre la asistencia de
      P1-12) y aguantar frena al jugador, recupera stamina y retrasa la entrada
      de los rivales cercanos. Sonda: `tools/M3DPrePlayChoiceProbe.tscn`.
- [x] **P1-14 · Cambio de ritmo.** Sprint corto con costo de stamina y frenada
      con inercia real.
      *Hecho:* `engine/match/m3d/Momentum.gd` (puro) separa aceleración viva
      (`38 m/s²`) de frenada con inercia (`20` normal, `16` con balón, `12`
      viniendo de sprint) y calcula el gasto de estamina (`0.006/s` de sprint
      más `0.010/s` por nivel de multi-toque). `SoccerPlayer` usa esos ritmos al
      acercar su velocidad a la deseada, así que soltar el mando ya no planta al
      jugador en seco; `SoccerMatch` cobra la estamina del sprint real y, sin
      fondo físico, corta sprint y boost. Sonda:
      `tools/M3DMomentumProbe.tscn`.
- [ ] **P1-15 · Proteger el balón.** Poner el cuerpo entre el balón y el rival,
      con falta si el defensa te empuja.
- [ ] **P1-16 · Barrida.** Entrada deslizada con riesgo de falta y de quedar
      fuera de la jugada.
- [ ] **P1-17 · Entrada con timing.** Ventana de acierto; si llegás tarde, falta.
- [ ] **P1-18 · Quite de hombro.** Robar sin barrer, apoyado en fuerza.
- [ ] **P1-19 · Segundo toque.** Autopase para ganar el espacio y volver a
      arrancar.
- [ ] **P1-20 · Definición ante el portero.** Elegir colocado, picado o al
      cuerpo según cómo salga el arquero.
- [ ] **P1-21 · Fatiga dentro del gesto.** La zona verde se achica al 85' y con
      la estamina baja, no solo el atributo.
- [ ] **P1-22 · Juego ambiental en la cancha.** Que se muevan compañeros y
      rivales entre tus momentos, no solo durante tu jugada.
- [ ] **P1-23 · Calificación por gesto.** Perfecto / Bueno / Flojo, racha y XP
      directa al final del partido.
- [ ] **P1-24 · Retos del DT antes del partido.** Objetivo concreto ("ganá 3
      duelos", "no pierdas el balón") con recompensa de confianza.
- [ ] **P1-25 · Modo práctica en Entrenamiento.** Repetir el minijuego del foco
      sin consecuencias de carrera.
- [ ] **P1-26 · Dificultad del partido.** Un ajuste aparte de la dificultad de
      progresión: arquero, presión y precisión rival.
- [ ] **P1-27 · Reanudación rápida tras falta.** Que el partido no se congele
      10 segundos entre el silbato y el tiro libre.
- [ ] **P1-28 · Charla táctica en pausa.** Cambiar de banda, subir la línea o
      pedir presión sin salir del partido.
- [ ] **P1-29 · Tiros libres ensayados.** Elegir jugada antes de patear (directo,
      centro, toque corto).
- [ ] **P1-30 · Córners ensayados.** Primer palo, segundo palo o jugada corta,
      con movimiento de los compañeros.
- [ ] **P1-31 · Rebote y segunda jugada.** Que el palo y el arquero dejen balón
      vivo (fuera de la tanda de penaltis).
- [ ] **P1-32 · Control de temperatura del partido.** Que el marcador y el
      minuto cambien la actitud de la IA (conservar, arriesgar, matar el
      partido).

---

### 13.3 P1 — IA de compañeros, rivales y arqueros

- [x] **P1-33 · IA por atributos dentro de tu jugada.** Hoy solo corre en el
      juego ambiental y en el desmarque; llevarla a toda la oportunidad.
      *Hecho:* `engine/match/m3d/AiTuning.gd` centraliza las probabilidades y
      distancias derivadas de atributos (passing, shooting, composure,
      decision_making, strength, speed). `AiBrain` las usa al decidir pase,
      centro, tiro, apoyo, desmarque, marcaje, presión y plancha, también
      durante tus momentos. Sonda: `tools/AiTuningProbe.tscn`.
- [x] **P1-34 · Etapa 3 completa.** Compañeros y rivales gobernados por sus
      atributos durante toda la jugada, no por el libreto.
      *Hecho:* con `AiTuning` la IA deja de usar probabilidades fijas en todas
      las fases (con balón, apoyo, defensa, balón suelto y portero); la
      selección de pase pondera el espacio libre según el `passing` del
      pasador. Misma sonda que P1-33.
- [ ] **P1-35 · Desmarque del compañero.** Que ofrezca la línea de pase y no se
      quede quieto al lado del marcador.
- [ ] **P1-36 · Arrastre de marca.** Que un compañero se lleve al defensor y
      libere el espacio para vos.
- [ ] **P1-37 · Apoyo en tercer hombre.** Pase–apoyo–pase para salir de la
      presión.
- [ ] **P1-38 · Anticipación del defensor.** Cortar la línea de pase antes de
      que salga, no después.
- [ ] **P1-39 · Basculación y cobertura.** La línea defensiva se mueve junta y
      cubre el hueco del lateral.
- [ ] **P1-40 · Línea de 4 y fuera de juego.** Que la defensa suba y arriesgue
      el offside.
- [ ] **P1-41 · Presión coordinada y trampas.** Dos o tres jugadores cierran
      el circuito de pase, no todos corren al balón.
- [ ] **P1-42 · Visión del mediocampista.** Encontrar al hombre libre y cambiar
      el frente.
- [ ] **P1-43 · Desmarque del delantero antes de recibir.** Movimiento previo,
      no solo cuando ya tiene la pelota.
- [ ] **P1-44 · Extremo 1 contra 1.** Encara, tira el centro o se mete al área
      según su atributo de regate.
- [ ] **P1-45 · Lateral que se incorpora.** Subida por banda y cobertura del
      pivote.
- [ ] **P1-46 · Arquero con reflejos.** Ver volar la pelota, deslizar alto/bajo
      y llegar a los rincones.
- [ ] **P1-47 · Arquero que achica.** Salir a cerrar el ángulo en el mano a mano.
- [ ] **P1-48 · Arquero en penales.** Leer el gesto, elegir palo con acierto
      según su atributo y no quedarse clavado.
- [ ] **P1-49 · Distribución del arquero.** Sacar corto o largo según la presión.
- [ ] **P1-50 · Fatiga en la IA.** Que los rivales también pierdan velocidad y
      precisión en el segundo tiempo.
- [ ] **P1-51 · Errores según atributos.** Los defensas flojos fallan pases y
      los delanteros flojos erran el arco; no todos son iguales.
- [ ] **P1-52 · Dificultad adaptativa.** Ajustar presión y precisión rival al
      nivel del jugador y al marcador.
- [ ] **P1-53 · Marcajes en córner.** Cada defensor toma un hombre y el arquero
      manda.
- [ ] **P1-54 · Contraataque tras recuperación.** Transición rápida de defensa
      a ataque con tres o cuatro jugadores.
- [ ] **P1-55 · Comportamiento del banquillo.** Calentar, festejar y reaccionar
      a los cambios.
- [ ] **P1-56 · IA del árbitro asistente.** Que el juez de línea acompañe la
      jugada y no se quede congelado.

---

### 13.4 P1 — Animaciones

- [ ] **P1-57 · Pase.** Animación propia con pierna de apoyo y seguimiento.
- [ ] **P1-58 · Remate.** Cuerpo, cadera y brazo; distinta según potencia.
- [ ] **P1-59 · Regate.** Cambio de peso y amague.
- [ ] **P1-60 · Barrida.** Entrada, caída y levantada.
- [ ] **P1-61 · Estirada del arquero.** Volada alta, media y baja, con caída.
- [ ] **P1-62 · Seis celebraciones de gol.** Distintas, con personalidad y
      duración suficiente.
- [ ] **P1-63 · Cabezazo.** Salto, impulso y contacto.
- [ ] **P1-64 · Choque y protección.** Hombro a hombro y caída.
- [ ] **P1-65 · Lesión y camilla.** Salida del jugador lesionado.
- [ ] **P1-66 · Árbitro completo.** Pitido inicial, entretiempo, final, amarilla
      y roja.
- [ ] **P1-67 · DT en la banda.** Festeja, se enoja y da instrucciones.
- [ ] **P1-68 · Banquillo vivo.** Suplentes que siguen la jugada y festejan.
- [ ] **P1-69 · Túnel.** Caminata de entrada y salida con ritmo propio.
- [ ] **P1-70 · Entrada al campo.** Saludo, himno y formación.
- [x] **P1-71 · Giros de 180°.** Sin patinaje ni teletransporte.
      *Hecho:* el cuerpo gira con `_turn_toward` a velocidad angular limitada
      (más lenta cuanto más cerrado es el giro) y sin sobrepasar la dirección
      objetivo; además `turn_speed_factor` reduce la velocidad al arrancar en
      sentido contrario. Misma sonda que P0-11 (`tools/M3DMotionProbe.tscn`).
- [ ] **P1-72 · Carrera lateral y de espaldas.** Que se vea natural, no un
      sprite girado.
- [ ] **P1-73 · Cambio de jugador.** Entra, se acomoda y saluda.
- [ ] **P1-74 · Festejo con compañeros.** Abrazo y vuelta al medio.
- [ ] **P1-75 · Levantar el trofeo.** Ceremonia con brazos y cámara.
- [ ] **P1-76 · Calentamiento.** Movilidad en la banda antes de entrar.
- [ ] **P1-77 · Reacción al gol rival.** Cabizbajo, reclamo o aplauso.
- [ ] **P1-78 · Protesta y tarjeta.** Gesto de protesta y reacción a la amarilla.
- [ ] **P1-79 · Respiración y cansancio.** Ampliar lo ya hecho: manos en
      rodillas, caminar entre jugadas.

---

### 13.5 P1 — Cámara, HUD y presentación del partido

- [ ] **P1-80 · Tres cámaras.** Arco (actual), TV lateral e isométrica.
- [ ] **P1-81 · Zoom configurable.** Que el jugador elija qué tan cerca quiere
      la cámara detrás.
- [ ] **P1-82 · Cámara de gol.** Plano del balón entrando y del goleador.
- [ ] **P1-83 · Cámara de túnel.** Plano lateral de la salida.
- [ ] **P1-84 · Cámara de penal.** Detrás del pateador, como en TV.
- [ ] **P1-85 · Cámara de tanda.** Plano fijo detrás del punto de penal.
- [ ] **P1-86 · Cámara de repetición.** Ángulos distintos al original.
- [ ] **P1-87 · Shake configurable.** Que el temblor de cámara se pueda apagar.
- [ ] **P1-88 · FOV dinámico.** Abrir el campo al sprintar y cerrarlo al frenar.
- [ ] **P1-89 · Letterbox de cine.** Barras negras en celebraciones y
      repeticiones.
- [ ] **P1-90 · HUD oculto en repetición.** Solo marcador mínimo.
- [ ] **P1-91 · Marcador con global.** Mostrar ida, vuelta y global en las
      eliminatorias.
- [ ] **P1-92 · Indicador de global en el HUD.** Que no haya que abrir el
      resumen para saber cómo va la serie.
- [ ] **P1-93 · Reloj y descuento.** Minuto, tiempo añadido y aviso de los
      últimos minutos.
- [ ] **P1-94 · Cartel del goleador.** Nombre, minuto y asistente.
- [ ] **P1-95 · Cartel de cambio.** Quién entra y quién sale, con dorsal.
- [ ] **P1-96 · HUD configurable.** Elegir qué se ve: stamina, nombres, minimapa,
      indicador de pase.
- [ ] **P1-97 · Resumen táctico en pausa.** Posesión, tiros y mapa de calor
      simple.
- [ ] **P1-98 · Aviso de récord.** Cuando el jugador rompe una marca personal o
      de club.

---

### 13.6 P1 — Arbitraje y reglas

- [ ] **P1-99 · Fuera de juego.** Línea, momento del pase y decisión del juez.
- [ ] **P1-100 · Ley de la ventaja.** Que el árbitro deje seguir si hay ventaja
      y amoneste después.
- [ ] **P1-101 · Amarilla por acumulación.** Contador por jugador y suspensión
      por ciclo.
- [ ] **P1-102 · Segunda amarilla.** Expulsión automática.
- [ ] **P1-103 · Roja directa.** Y jugar con 10 el resto del partido.
- [ ] **P1-104 · Penal por mano.** Mano en el área, deliberada o no.
- [ ] **P1-105 · Barrera.** Distancia reglamentaria y salto de la barrera.
- [ ] **P1-106 · Ley del pase atrás.** El arquero no puede tomar con la mano un
      pase de un compañero.
- [ ] **P1-107 · Tiempo añadido.** Calculado por cambios, faltas y lesiones.
- [ ] **P1-108 · Sustituciones reglamentarias.** límite de cambios y ventanas.
- [ ] **P1-109 · Lesión en cancha.** Detener el juego, atender y reanudar.
- [ ] **P1-110 · Revisión de VAR.** Pantalla, decisión y explicación.
- [ ] **P1-111 · Protesta y tarjeta.** Que protestar de más cueste amarilla.
- [ ] **P1-112 · Árbitro de área y cuarto árbitro.** Presencia y cartel de
      cambios.
- [ ] **P1-113 · Criterio de penalti.** Que no se cobre cualquier contacto y
      que el árbitro estricto cobre más.
- [ ] **P1-114 · Reglas por competición.** Copa con prórroga y tanda, liga con
      puntos, supercopa a partido único.

---

### 13.7 P1 — Tanda, eliminatorias y global

- [ ] **P1-115 · Orden de tiradores.** Elegir los cinco (y el orden) antes de
      la tanda.
- [ ] **P1-116 · Presión del marcador.** Que el que patea con ventaja sienta
      menos presión y el que va perdiendo más.
- [ ] **P1-117 · Arquero elige palo.** Decisión visible antes de cada remate.
- [ ] **P1-118 · Cámara de tanda.** Plano fijo y legible, sin mareos.
- [ ] **P1-119 · Estadísticas de tanda.** Goles, atajadas y errores por tirador.
- [ ] **P1-120 · Historial de tandas.** Guardar quién ganó cada serie.
- [ ] **P1-121 · Prórroga con cansancio real.** La stamina arrastrada del tiempo
      reglamentario pesa en el alargue.
- [ ] **P1-122 · Sorteo de localía.** Que la ida y la vuelta no siempre caigan
      igual.
- [ ] **P1-123 · Global en selecciones.** Misma lógica que clubes, sin excepción.
- [ ] **P1-124 · Global en Mundial de Clubes.** Verificar el acarreo en el
      cuadro completo.
- [ ] **P1-125 · Calendario de la serie.** Que las dos legs aparezcan en el
      calendario y no se pisen con la liga.
- [ ] **P1-126 · Regla de goles de visitante.** Opcional por competición, bien
      explicada en la previa.

---

### 13.8 P2 — Estadísticas y análisis

- [ ] **P2-01 · Posesión real.** Calculada por tiempo de control, no por
      estimación.
- [ ] **P2-02 · xG (goles esperados).** Por remate, con distancia y ángulo.
- [ ] **P2-03 · Mapa de tiros.** Dónde se pateó y cuáles fueron al arco.
- [ ] **P2-04 · Estadísticas por jugador.** Goles, asistencias, pases, duelos.
- [ ] **P2-05 · Nota en vivo.** Que la calificación suba o baje durante el
      partido.
- [ ] **P2-06 · Historial de enfrentamientos.** Últimos cruces y resultados.
- [ ] **P2-07 · Resumen al descanso.** Marcador, tiros y lo mejor del primer
      tiempo.
- [ ] **P2-08 · Racha de forma.** Últimos cinco partidos con nota.
- [ ] **P2-09 · Comparación con el rival.** Atributos y forma de ambos equipos.
- [ ] **P2-10 · Mejores jugadas del partido.** Top 3 con miniatura.
- [ ] **P2-11 · MVP con criterio.** Que salga de eventos reales y no del
      marcador.
- [ ] **P2-12 · Asistencias y ocasiones creadas.** Contarlas bien.
- [ ] **P2-13 · Recuperaciones y pérdidas.** Para mediocampistas y defensas.
- [ ] **P2-14 · Errores que cuestan gol.** Que afecten la nota y la prensa.
- [ ] **P2-15 · Exportar el resumen.** Compartir la ficha del partido.

---

### 13.9 P2 — Rendimiento y compatibilidad

- [ ] **P2-16 · Oclusión y culling.** No dibujar lo que la cámara no ve.
- [ ] **P2-17 · LOD de jugadores y estadio.** Menos detalle a distancia.
- [ ] **P2-18 · Público con MultiMesh.** Miles de personas en pocas llamadas.
- [ ] **P2-19 · Shaders precompilados.** Evitar el tirón del primer uso.
- [ ] **P2-20 · Carga asíncrona de escenas.** Sin pantallas negras largas.
- [ ] **P2-21 · Memoria de texturas.** Auditar el uso en gama baja.
- [ ] **P2-22 · Límite de FPS configurable.** 30 / 60 / libre, y modo batería.
- [ ] **P2-23 · Perfil por gama.** Detectar el teléfono y bajar sombras, MSAA y
      resolución.
- [ ] **P2-24 · Overlay de diagnóstico.** FPS, draw calls, memoria y escala
      actual, solo en debug.
- [ ] **P2-25 · Menos draw calls en el estadio.** Unir mallas estáticas.
- [ ] **P2-26 · Partículas controladas.** Limitar el confeti y el humo del túnel
      según `reduce_motion`.
- [ ] **P2-27 · Audio en streaming.** No cargar toda la música en memoria.
- [ ] **P2-28 · Pool de objetos.** Evitar instanciar y liberar por frame.
- [ ] **P2-29 · Cero allocations en el bucle caliente.** Revisar `_physics_process`.
- [ ] **P2-30 · Pruebas en gama baja.** Un Android de 4 GB como referencia.
- [ ] **P2-31 · Arranque más rápido.** Precarga del Hub y del mundo.
- [ ] **P2-32 · Tamaño del APK.** Revisar assets duplicados y compresión.

---

### 13.10 P2 — Partido por decisiones / 2D

- [ ] **P2-33 · Reactivar `live_play` como modo aparte.** Sin tocar el modo por
      defecto.
- [ ] **P2-34 · Gestos legibles.** Tutorial corto y práctica antes de usarlo.
- [ ] **P2-35 · De fichas a sprites.** Tu personaje en 8 direcciones.
- [ ] **P2-36 · Arqueros con estirada.** Buzo y guantes.
- [ ] **P2-37 · Árbitro en cancha.** Que acompañe la jugada.
- [ ] **P2-38 · Tres cámaras 2D.** Arco, lateral e isométrica.
- [ ] **P2-39 · Física simple de la pelota.** Pique y efecto.
- [ ] **P2-40 · Jugadas encadenadas.** Que el gesto no cierre la jugada.
- [ ] **P2-41 · HUD del modo 2D.** Marcador, stamina y controles.
- [ ] **P2-42 · Guardado de la posición táctica.** Que no se reinicie la
      formación al cambiar de pantalla.
- [ ] **P2-43 · Accesibilidad táctil.** Zonas grandes y sin gestos de precisión.
- [ ] **P2-44 · Decidir el futuro del modo.** Terminarlo o retirarlo del todo,
      pero no dejarlo a medias.

---

### 13.11 P2 — Carrera y progresión

- [ ] **P2-45 · Entrenamiento específico.** Elegir el atributo a entrenar y ver
      la curva semana a semana.
- [ ] **P2-46 · Mentor.** Un veterano que acelera el aprendizaje de un atributo.
- [ ] **P2-47 · Decadencia por edad.** Que a los 33+ cueste mantener velocidad.
- [ ] **P2-48 · Lesiones con recuperación.** Días, rehabilitación y riesgo de
      recaída.
- [ ] **P2-49 · Forma física.** Un estado entre "en racha" y "fundido".
- [ ] **P2-50 · Moral.** Que afecte confianza, prensa y rendimiento.
- [ ] **P2-51 · Química con compañeros.** Pases y desmarques mejores con el
      tiempo.
- [ ] **P2-52 · Rol en el equipo.** Titular, rotación, suplente o descartado.
- [ ] **P2-53 · Promesas del DT.** "Si rendís, te doy la cinta"; se cumplen o
      se rompen.
- [ ] **P2-54 · Objetivos personales.** Goles, asistencias, títulos, minutos.
- [ ] **P2-55 · Capitanía con peso real.** Charla previa, decisiones y presión.
- [ ] **P2-56 · Decisión de retiro.** Elegir cuándo colgar los botines.
- [ ] **P2-57 · Legado completo.** Récords, camiseta retirada y estatua.
- [ ] **P2-58 · Historial de carrera.** Trayectoria club por club, año por año.
- [ ] **P2-59 · Récords personales.** Más goles, más partidos, más asistencias.
- [ ] **P2-60 · Comparación con leyendas.** Dónde estás en la historia.
- [ ] **P2-61 · Rebalanceo de progresión.** Revisar curvas con partidas largas.
- [ ] **P2-62 · Árbol de habilidades.** Revisar que cada rama tenga sentido por
      posición.
- [ ] **P2-63 · Especializaciones.** Definidor, organizador, stopper, carrilero.
- [ ] **P2-64 · Editor de apariencia.** Cambiar corte, barba y tinte con el
      tiempo.
- [ ] **P2-65 · Segundo rol.** Aprender una posición secundaria con minutos.
- [ ] **P2-66 · Compañero rival interno.** Un juvenil que te disputa el puesto.

---

### 13.12 P2 — Mercado, contratos y finanzas

- [ ] **P2-67 · Cláusula de rescisión.** Visible y negociable.
- [ ] **P2-68 · Primas por firmar.** Parte del atractivo de una oferta.
- [ ] **P2-69 · Impuestos.** Que el sueldo neto no sea el bruto.
- [ ] **P2-70 · Patrocinios personales.** Más allá de guayos y club.
- [ ] **P2-71 · Inversiones con riesgo real.** Ganar o perder, no solo ganar.
- [ ] **P2-72 · Agente con más agencia.** Que consiga ofertas y no solo cobre.
- [ ] **P2-73 · Negociación con el club.** Pedir aumento, rol o salida.
- [ ] **P2-74 · Ofertas de último minuto.** Deadline day con decisión.
- [ ] **P2-75 · Mercado de invierno.** Ventana corta con menos movimiento.
- [ ] **P2-76 · Cesiones con opción de compra.** Y obligación.
- [ ] **P2-77 · Trueques.** Jugador por jugador con vuelta de dinero.
- [ ] **P2-78 · Salarios de la IA.** Coherentes con el nivel del club.
- [ ] **P2-79 · Valores de mercado.** Actualizados por edad, forma y contrato.
- [ ] **P2-80 · Bonos por objetivos.** Goles, títulos, clasificación.
- [ ] **P2-81 · Dorsal y número.** Elegirlo y que cambie al fichar.
- [ ] **P2-82 · Negociación con el DT.** Rol y minutos antes de firmar.
- [ ] **P2-83 · Ofertas de selección.** Convocatorias y renuncias.
- [ ] **P2-84 · Ruptura de contrato.** Costo y consecuencias.

---

### 13.13 P2 — Vida, prensa y vínculos

- [ ] **P2-85 · Familia.** Padres, hermanos y apoyo en los momentos duros.
- [ ] **P2-86 · Pareja con arco propio.** Conocer, salir, crisis y ruptura.
- [ ] **P2-87 · Amistades.** Compañeros y amistades fuera del fútbol.
- [ ] **P2-88 · Redes sociales con consecuencias.** Un posteo puede costar caro.
- [ ] **P2-89 · Prensa con memoria.** Que recuerde lo que dijiste hace meses.
- [ ] **P2-90 · Entrevistas ramificadas.** Respuestas que abren o cierran puertas.
- [ ] **P2-91 · Polémicas y escándalos.** Gestión de crisis con el club.
- [ ] **P2-92 · Bienestar mental.** Racha, presión y descanso.
- [ ] **P2-93 · Descanso y pretemporada.** Vacaciones que recuperan forma.
- [ ] **P2-94 · Viajes y concentraciones.** Logística antes de partidos grandes.
- [ ] **P2-95 · Idiomas.** Adaptación al país y efecto en la relación con el DT.
- [ ] **P2-96 · Estudios.** Formación paralela para el después del retiro.
- [ ] **P2-97 · Hobbies.** Actividades que cambian la personalidad.
- [ ] **P2-98 · Fundación.** Proyecto social que deja legado.
- [ ] **P2-99 · Vida después del retiro.** Rol de embajador o DT.
- [ ] **P2-100 · Eventos de vestuario.** Conflictos y liderazgos internos.

---

### 13.14 P2 — Mundo y competiciones

- [ ] **P2-101 · Ascensos y descensos visibles.** Que se vean en la clasificación.
- [ ] **P2-102 · Copas nacionales completas.** Cuadro y sorpresas.
- [ ] **P2-103 · Continentales con coeficiente.** Que el sorteo dependa del ránking.
- [ ] **P2-104 · Mundial con eliminatorias.** Camino completo hasta la cita.
- [ ] **P2-105 · Selecciones con identidad.** Estilo y jugadores propios.
- [ ] **P2-106 · Mercado global coherente.** Que los clubes ricos compren caro.
- [ ] **P2-107 · Noticias del mundo.** Más variedad y menos repetición.
- [ ] **P2-108 · Ránking mundial de clubes y jugadores.** Actualizado por temporada.
- [ ] **P2-109 · `WorldPulse` más vivo.** Reacciones y tendencias.
- [ ] **P2-110 · Calendario FIFA.** Ventanas y fechas coherentes.
- [ ] **P2-111 · Ventanas de mercado.** Apertura y cierre visibles.
- [ ] **P2-112 · Premios de temporada.** Gala completa y discursos.
- [ ] **P2-113 · Rivalidades con contexto.** Clásico con previa especial.
- [ ] **P2-114 · Historia del mundo.** Récords y campeones por temporada.

---

### 13.15 P2 — UI/UX y accesibilidad

- [ ] **P2-115 · Safe area.** Nada tapado por notch ni gestos del sistema.
- [ ] **P2-116 · Escalado de texto.** Ya existe; revisar todas las pantallas.
- [ ] **P2-117 · Modo daltonismo.** Paletas alternativas para marcadores.
- [ ] **P2-118 · Subtítulos.** Para narración y sonidos clave.
- [ ] **P2-119 · Remapeo / sensibilidad.** Gestos y zonas táctiles.
- [ ] **P2-120 · Vibración configurable.** Intensidad y por evento.
- [ ] **P2-121 · Uso con una mano.** Que lo importante quede abajo.
- [ ] **P2-122 · Navegación clara.** Volver siempre al lugar esperado.
- [ ] **P2-123 · Botones grandes.** Objetivos táctiles de 48 dp mínimo.
- [ ] **P2-124 · Confirmaciones útiles.** Solo para acciones destructivas.
- [ ] **P2-125 · Feedback inmediato.** Sonido, vibración y animación en cada toque.
- [ ] **P2-126 · Tutoriales contextuales.** Explicar solo cuando hace falta.
- [ ] **P2-127 · Tooltips de atributos.** Qué hace cada stat, sin adivinar.
- [ ] **P2-128 · Filtros y búsqueda.** En tablas largas (mercado, plantilla).
- [ ] **P2-129 · Ordenar tablas.** Por cualquier columna.
- [ ] **P2-130 · Accesos directos.** Del Hub a lo que más usás.
- [ ] **P2-131 · Tema claro/oscuro.** O al menos contraste configurable.
- [ ] **P2-132 · Animaciones de UI.** Transiciones suaves y cancelables.
- [ ] **P2-133 · Pantallas de carga.** Progreso real, no spinner infinito.
- [ ] **P2-134 · Manejo de errores.** Mensaje claro si falta un save o un asset.

---

### 13.16 P2 — Audio

- [ ] **P2-135 · Música contextual.** Distinta en menú, previa, partido y final.
- [ ] **P2-136 · Himnos.** De selección y de copa continental.
- [ ] **P2-137 · Narración de jugadas.** Voz o texto locutado.
- [ ] **P2-138 · Comentarios.** Frases que reaccionen al marcador.
- [ ] **P2-139 · SFX por estadio.** Silbato y ambiente propios de cada cancha.
- [ ] **P2-140 · Mezcla por canal.** Música, ambiente, efectos y voz separados.
- [ ] **P2-141 · `ducking` ya existe.** Extenderlo a la narración.
- [ ] **P2-142 · Audio en repetición.** Que no se corte el ambiente.
- [ ] **P2-143 · Ambiente por hora y clima.** Día, noche, lluvia.
- [ ] **P2-144 · Cánticos.** Que la hinchada cante el nombre del club.
- [ ] **P2-145 · Silencio de menú.** Modo sin música para partidas largas.
- [ ] **P2-146 · Accesibilidad auditiva.** Avisos visuales de los sonidos clave.

---

### 13.17 P2 — Arte y contenido

- [ ] **P2-147 · Seis celebraciones de gol** (arte y animación propias).
- [ ] **P2-148 · Árbitro completo** (arte de tarjetas y gestos).
- [ ] **P2-149 · DT en la banda.**
- [ ] **P2-150 · Ceremonias.** Levantar el trofeo, Balón de Oro y gala.
- [ ] **P2-151 · Ediciones de oro.** Desbloqueo por logros y ropa de patrocinador.
- [ ] **P2-152 · Diseños de camiseta.** Rayas, mitades y banda + logo.
- [ ] **P2-153 · Vivienda y coche** en pixel art (Estilo de vida).
- [ ] **P2-154 · Canas con la edad.** Solo tinte, gratis.
- [ ] **P2-155 · Escudos.** Set pixel art para los que siguen en `Crest.gd`.
- [ ] **P2-156 · Trofeos.** Arte propio para las familias que caen al fallback.
- [ ] **P2-157 · Fondo de estadio** (`StadiumBg`) en pixel art.
- [ ] **P2-158 · Banderas de países** en pixel art.
- [ ] **P2-159 · Menús y UI.** Botones, marcos e iconos del Hub en un mismo estilo.
- [ ] **P2-160 · Estadios distintos.** Que no todos se vean iguales.
- [ ] **P2-161 · Sombras según la hora.** Mediodía, tarde y noche.
- [ ] **P2-162 · Tribuna viva.** Público que se mueve, se para y festeja.
- [ ] **P2-163 · Animar objetos.** Camarógrafo, barra, marcador, túnel y camilla.
- [ ] **P2-164 · Minijuegos del paquete de 15.** Regate con combos y jugadas de
      lujo incluidos.
- [ ] **P2-165 · Retratos de jugadores.** Más variedad y coherencia.
- [ ] **P2-166 · Celebraciones de título.** Vuelta olímpica y foto de equipo.
- [ ] **P2-167 · Clima.** Lluvia, nieve y viento con efecto en el balón.
- [ ] **P2-168 · Césped.** Cortes, desgaste y marcas de los botines.
- [ ] **P2-169 · Poner al día las probes viejas.** `PixelAvatarProbe` y compañía.

---

### 13.18 P2 — Persistencia, herramientas y proyecto

- [ ] **P2-170 · Exportar e importar partida.** Archivo para mover entre teléfonos.
- [ ] **P2-171 · Copia en la nube.** Opcional y sin obligar a cuenta.
- [ ] **P2-172 · Backup automático.** Una copia por día, rotativa.
- [ ] **P2-173 · Recuperación de save corrupto.** Leer lo que se pueda.
- [ ] **P2-174 · Versión de save visible.** En Ajustes, con fecha.
- [ ] **P2-175 · Más slots.** O slots ilimitados con nombre.
- [ ] **P2-176 · Tests de migración.** Un save por versión que se cargue solo.
- [ ] **P2-177 · Sonda automática en cada cambio.** Que `PROBE OK` sea requisito.
- [ ] **P2-178 · CI local.** Script que compile, sonde y exporte en un paso.
- [ ] **P2-179 · Control de versiones.** Mover el proyecto a Git con historial.
- [ ] **P2-180 · Documentación viva.** Este archivo y `CLAUDE.md` al día.
- [ ] **P2-181 · Telemetría local.** Registrar FPS y errores en un log propio.
- [ ] **P2-182 · Modo debug.** Saltar a un día, forzar un evento, ver variables.
- [ ] **P2-183 · Editor de datos.** Ver y tocar ligas/clubes sin recompilar.
- [ ] **P2-184 · Probes nuevas.** Cobertura para tanda, global y estadísticas.
- [ ] **P2-185 · Limpieza de assets.** Duplicados y texturas sin usar.

---

### 13.19 Ideas grandes / backlog abierto

> No están comprometidas: son direcciones posibles si el juego crece.

- [ ] **P2-186 · Modo entrenador.** Empezar la carrera en el banquillo.
- [ ] **P2-187 · Modo club.** Dirigir un equipo entero, no un jugador.
- [ ] **P2-188 · Multijugador local.** Partidos rápidos en el mismo teléfono.
- [ ] **P2-189 · Editor de torneos.** Crear copas y ligas propias.
- [ ] **P2-190 · Modo desafío.** Escenarios históricos con objetivo.
- [ ] **P2-191 · Carrera rápida.** Simular temporadas en minutos.
- [ ] **P2-192 · Modo leyenda.** Revivir carreras de jugadores ficticios.
- [ ] **P2-193 · Compartir highlights.** Video corto del gol o la atajada.
- [ ] **P2-194 · Logros.** Integración con el sistema del teléfono.
- [ ] **P2-195 · Estadísticas globales.** Récords entre partidas.
- [ ] **P2-196 · Modo espectador.** Mirar partidos de la IA.

---

## 14. Limitaciones conocidas

1. **VAR cosmético:** hoy no anula goles; es una decisión de diseño pendiente.
2. **Árbitro sin personalidad:** todos pitan igual.
3. **Sin repetición de la tanda:** la tanda se juega, pero no se puede rever.
4. **Partido en vivo apagado:** el código de `match_live` queda estacionado.
5. **Cámara de cancha fija en "arco":** las opciones TV/isométrica se ignoran
   a propósito.
6. **Sin control de versiones:** el proyecto no es un repo Git; los cambios no
   tienen historial.
7. **`CLAUDE.md` desactualizado:** menciona esquema v11 y Godot 4.3; el código
   va por v35 y 4.7.2.
8. **3 slots** de guardado; no hay nube ni exportación de partidas.
9. **La sonda de gameplay tarda varios minutos** y debe correr en segundo
   plano.
10. **Dependencia del APK de depuración:** la firma se rehace en cada export y
    hay que verificar `package/signed=true`.

---

## 15. Checklist de pruebas en el teléfono

Instalar el APK y probar, en orden:

### Partido 3D

- [ ] La cámara queda **detrás del jugador** y más cerca en todas las jugadas.
- [ ] Los **pases fuertes** se controlan (no se escapan).
- [ ] **Faltas:** dentro del área → penal; fuera → tiro libre en el lugar.
- [ ] **Goles:** variedad de jugadas y ningún **gol fantasma**.
- [ ] **No goles:** la ocasión termina en "¡NO ENTRA!" sin mover el marcador.
- [ ] **Celebración:** el goleador corre al banderín y celebra de frente.
- [ ] **Túnel:** salida calmada, sin deslizamientos.
- [ ] **Estamina:** la barra baja y se nota el cansancio al correr.
- [ ] **"Pedir entrar" / "Pedir salir":** el técnico decide y el avatar cambia.
- [ ] **Ritmo:** Detallado, Normal y Rápido se sienten distintos.
- [ ] **Estadísticas:** `on_target ≤ shots` y sin doble conteo.
- [ ] **Repetición:** fluida, sin acelerones.

### Global y tanda

- [ ] Ida 3–2 → la vuelta **muestra 3–2** en el global (no 0–0).
- [ ] Si el global queda empatado, hay **prórroga** y luego **tanda**.
- [ ] La tanda **no tiene rebote**.
- [ ] El ganador de la tanda sale del **marcador real** (+ muerte súbita).

### Rendimiento

- [ ] **FPS estables** (objetivo 50–58) con la resolución adaptativa.
- [ ] Sin tirones en el túnel, celebraciones ni repetición.
- [ ] El HUD no parpadea ni se traba.

### Carrera

- [ ] El **rollover** de temporada cierra bien y no rompe el save (v35).
- [ ] Las **preferencias** sobreviven al cerrar la app.
- [ ] Los **3 slots** cargan y guardan sin mezclarse.

---

*Fin del documento. Mantener sincronizado con el código: si cambia un sistema,
se actualiza su sección y, si cambia el esquema, se agrega la migración.*
