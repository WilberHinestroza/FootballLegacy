# Football Career (Godot) — Carrera individual de futbolista

Juego de fútbol para Android, carrera **individual** (un solo futbolista,
no un club), construido aplicando los aprendizajes de **Football Legacy**
(Kotlin/Jetpack Compose/Room). Este documento mapea cada aprendizaje a su
equivalente concreto en este proyecto Godot y lleva el estado real del
desarrollo — si algo aquí no coincide con el código, manda el código.

## Estructura de carpetas

```
FootballCareer/
├── project.godot
├── autoloads/                 → Singletons globales
│   ├── SaveManager.gd         → persistencia + migraciones de esquema (hoy v11)
│   ├── WorldTickEngine.gd     → ÚNICA fuente de avance de día; cachea mundo/temporada
│   └── MatchState.gd          → estado compartido entre PreMatch/Match/MatchSummary/Interview
├── data/                      → Resources (equivalente a Entities de Room)
│   ├── PlayerData.gd          → el futbolista del usuario (esquema versionado)
│   ├── ClubData.gd            → club genérico (también sirve para selecciones, league_id=-1)
│   ├── CoachData.gd           → entrenador (generado, no persistido)
│   ├── LeagueData.gd          → una liga (formato, nº equipos, reputación...)
│   ├── Positions.gd           → 16 posiciones detalladas -> categoría amplia GK/DF/MF/ST
│   └── Countries.gd           → 199 países (desplegable de creación de personaje)
├── engine/
│   ├── world/                 → mundo determinista + calendario (mundo vivo, ver abajo)
│   │   ├── WorldFactory.gd        → genera 55 ligas/clubes/entrenadores desde world_seed
│   │   ├── SeasonCalendar.gd      → fixtures de liga (círculo) + cuadro de copa
│   │   ├── SeasonEngine.gd        → resultados (override real o sim) + progresión de copa
│   │   ├── MatchSimulator.gd      → marcador instantáneo para partidos de IA (no MatchEngine)
│   │   ├── LeagueTable.gd         → clasificación de cualquier liga
│   │   ├── CalendarUtils.gd       → epoch_day <-> fecha, season_start_year()
│   │   └── PersonalityQuiz.gd     → 20 preguntas, 5 al azar, 6 rasgos
│   ├── career/                 → todo lo que le pasa al JUGADOR fuera del partido
│   │   ├── CareerSetup.gd         → equipos de la prueba inicial + generación de ofertas
│   │   ├── CoachRelations.gd      → confianza con el entrenador + frase post-partido
│   │   ├── ContractEngine.gd      → sueldo, ingresos, renovación
│   │   ├── AgentEngine.gd         → representante (estrellas -> multiplicador de sueldo)
│   │   ├── LifestyleEngine.gd     → vivienda/coche (PlayerData.home_type/car_type)
│   │   ├── SponsorEngine.gd       → ofertas de patrocinio (estado persistente)
│   │   ├── PlayerDevelopment.gd   → progresión semanal de atributos + lesiones
│   │   ├── ObjectivesEngine.gd    → objetivo de temporada (club en vivo, jugador sorteado)
│   │   ├── PressGenerator.gd      → titulares de prensa tras el partido
│   │   └── InterviewEngine.gd     → zona mixta (partidos destacados)
│   └── match/                  → EL PARTIDO EN SÍ, no sabe nada de UI
│       ├── MatchEngine.gd         → simula, se detiene solo en momentos del usuario
│       ├── MatchTeam.gd           → XI genérico (club o selección), favor del entrenador
│       ├── MatchEvent.gd          → evento sellado, señal event_emitted
│       ├── DecisionResolver.gd    → TODA la matemática de éxito/fallo de un momento clave
│       └── MatchRatingCalculator.gd → rating 1-10 por eventos reales
└── scenes/                     → una carpeta por pantalla (Control + .gd a juego)
    ├── Start/, CharacterCreation/, Offers/             → arranque de carrera
    ├── Hub/                                            → pantalla central del loop
    ├── PreMatch/, Match/, MatchSummary/, PostMatchInterview/  → un partido, de punta a punta
    ├── Training/, Lifestyle/, SponsorOffer/, ContractDecision/ → gestión de carrera
    ├── Standings/, CupBracket/, WorldExplorer/, News/  → información de solo lectura
    └── (ui/common/ vacío — sin componentes reusables todavía)
```

## Mundo vivo (Fase 5+): el principio que sostiene todo lo demás

Las **55 ligas** del juego (`WorldFactory.LEAGUE_BLUEPRINTS`, datos reales
de país/tier/formato) se generan de forma **determinista** a partir de
`world_seed`: mismos clubes, mismos entrenadores, mismas plantillas en
cada carga. El **resultado de cualquier partido de IA es función pura**
de `(world_seed, fixture)` — nunca se simula ni se guarda por adelantado.
Eso significa:

- El save solo guarda `world_seed` + el día actual + tus resultados
  reales (los que jugaste tú) — nada de miles de partidos de otros.
- Puedes abrir la tabla o el cuadro de copa de **cualquiera** de las 55
  ligas en cualquier momento (`WorldExplorer`) y siempre está al día,
  aunque no la hayas mirado en semanas.
- Recargar la partida nunca cambia un resultado ya calculado.

## Mapeo directo Football Legacy → Godot

| Football Legacy (Kotlin) | Football Career (Godot) | Por qué |
|---|---|---|
| `DailyTickEngine` (Hilt singleton) | Autoload `WorldTickEngine.gd` | Fuente única de avance de día. Ninguna pantalla duplica esa lógica. |
| Room + `Migrations.kt` | Autoload `SaveManager.gd` + `schema_version` en JSON | Sin ORM con migraciones automáticas — disciplina manual (hoy 11 migraciones reales). |
| `hiltViewModel()` compartido vía nested nav graph | Autoload `MatchState.gd` | Evita instancias separadas por pantalla. |
| `CompletableDeferred` (contrato engine↔UI) | `await` sobre señal `decision_requested` | Pausar el engine hasta que la UI resuelva. |
| `MatchEvent` sellado + `AnimationRegistry` | `MatchEvent.gd` + señal `event_emitted` | El engine nunca sabe de Sprites/Tweens/sonido. |
| `MatchTeam` genérico (no `ClubEntity`) | `MatchTeam.gd` | Mismo motor sirve para club y selección nacional. |
| Techo `potential >= overall` | `PlayerData.ensure_potential_floor()` | Invariante de datos. |
| XI: GK real + 10 de campo, usuario siempre presente | `MatchTeam._build_lineup()` | Nunca elegir el equipo solo por overall. |
| Fórmulas de balance esparcidas (bug real en FL) | `DecisionResolver` / `ContractEngine` / `CoachRelations` / etc. centralizan cada una SU matemática | Un solo lugar por sistema, nunca duplicar una fórmula. |
| `InterviewEngine.kt` / `PressGenerator.kt` (prototipo Android) | `InterviewEngine.gd` / `PressGenerator.gd` | Portados y adaptados a los campos que existen aquí — ver nota abajo. |

## Prototipo de referencia (Android Studio, Kotlin/Compose)

Wilber compartió un prototipo jugable de Football Legacy con UI mucho más
rica que el placeholder de texto que tenía este proyecto. Se usó como
referencia de **diseño de pantalla y flujo**, nunca de código (no hay
Kotlin/Compose aquí): `MatchSummary`, `PostMatchInterview`, la cabecera
del `Hub` con color de club, el calendario semanal y el feed de prensa
nacieron mirando ese prototipo y adaptando los datos a los campos reales
que expone el motor de aquí (p. ej. "Pases clave" en vez de "Asistencias"
porque el motor no enlaza un pase con el gol que originó).

## Reglas que se mantienen desde el día 1 (no negociables)

1. **Un solo punto de avance de tiempo.** Todo lo que dependa del paso de
   un día pasa por `WorldTickEngine.advance_day()`.
2. **Cambio de esquema de guardado = aviso explícito.** Cualquier campo
   nuevo en `PlayerData`/`ClubData` es un cambio de esquema — anunciarlo
   antes de aplicarlo y añadir migración en `SaveManager._migrate_if_needed()`.
   Historial completo de las 11 versiones: cabecera de `SaveManager.gd`.
3. **El `MatchEngine` no sabe nada de UI.** Solo emite `MatchEvent`; las
   escenas deciden cómo animarlo/sonorizarlo.
4. **`potential >= overall` siempre.** Validar en creación de personaje y
   en cualquier pipeline de importación de datos futuro.
5. **Orden de posiciones consistente en toda la UI:** GK → DF → MF → ST.
6. **Balance centralizado por sistema, nunca disperso.** Cada mecánica
   (partido, contrato, confianza, desarrollo, vida) tiene UN archivo
   dueño de su matemática en `engine/career/` o `engine/match/`.

## Roadmap de fases

- [x] Fase 0 — Esqueleto compilando: MainMenu → Hub.
- [x] Fase 1 — `PlayerData`/`ClubData` como Resources + `SaveManager` con
      versión de esquema.
- [x] Fase 2 — `WorldTickEngine` con hooks documentados (todos con
      contenido real desde Fase 4-9, salvo prensa no ligada a partido).
- [x] Fase 3 — `MatchEngine` completo: momentos clave por posición,
      `DecisionResolver`, `MatchRatingCalculator`, minijuego de barra de
      poder, tarjetas y lesiones ambientales, penales en juego y tanda de
      penales con muerte súbita, sustitución básica del usuario, favor
      del entrenador (Fase 6) para forzar titularidad.
- [x] Fase 4 — Calendario de temporada y fixtures: `SeasonCalendar`
      (round-robin por método del círculo respetando el formato real de
      cada liga + cuadro de copa con byes).
- [x] Fase 5 — Motores de competición: `SeasonEngine` + `MatchSimulator`
      (mundo vivo, ver arriba), `LeagueTable`, progresión de copa,
      `WorldExplorer` para ver cualquiera de las 55 ligas.
- [x] Fase 6 — Entrenadores y confianza: `CoachData` + `CoachRelations`,
      favor del entrenador en la alineación, frase post-partido según su
      estilo. **Pendiente:** el entrenador nunca te saca del club por
      desconfianza — solo pasa en el vencimiento de contrato (Fase 8b).
- [x] Fase 7 — Entrenamiento, progresión, lesiones: `PlayerDevelopment`
      (tick semanal, foco elegible en `Training`), lesiones con días de
      baja reales que bloquean jugar.
- [x] Fase 8 — Contratos y finanzas: `ContractEngine` (sueldo, ingresos
      semanales), rollover de temporada, y **Fase 8b** — mercado de
      fichajes real al vencer el contrato (`ContractDecision`): renovar
      o fichar por un club externo, con reseteo de confianza si cambias.
- [x] Fase 9 — Vida personal: `LifestyleEngine` (vivienda/coche),
      `AgentEngine` (representante), `SponsorEngine` (patrocinios),
      `ObjectivesEngine` (objetivos de temporada), `PressGenerator`
      (prensa), `InterviewEngine` (zona mixta). Ver backlog abajo.
- [x] Fase 10 — Selección nacional, ciclo de Mundial, copas continentales
      (completa el 13-sep): `Confederations`/`NationalTeamFactory`
      (fuerza de los 199 países), `QualifyingEngine` (eliminatorias con
      formato real por confederación, ventanas FIFA, repechaje jugable),
      `WorldCupEngine` (Mundial de 48), `NationalCupEngine` (las 5 copas
      continentales), convocatoria por mérito, pantalla "Selecciones"
      (explorador por confederación + partido jugable + resumen con
      consecuencias reales de caps/goles/asistencias/títulos), y
      "Colección" (vitrina de trofeos de TODAS las carreras, en curso y
      retiradas, cross-save). Arte real ya en el juego para todo esto
      (ver nota de "arte" más abajo — ya NO es solo texto/color).

## Backlog de diseño heredado (buenas ideas de FL)

1. [x] Test de personalidad al crear personaje (5 de 20 preguntas al azar).
2. [x] Objetivos de temporada del club, ligados a `league_ambition`/`cup_ambition`.
3. [x] Objetivos de temporada del jugador, renovables cada año.
4. [x] Ofertas de patrocinador como estado persistente, no popup efímero.
5. [x] Mundial atado a ciclo real de 4 años con clasificación persistente
      — ver Fase 10 arriba.

## Cómo abrir el proyecto

1. El proyecto declara Godot 4.3 en `project.godot`, pero el único motor
   instalado en esta máquina es **Godot 4.7.2 estable** — al abrirlo con
   el editor, Godot puede reescribir `config/features` a `"4.7"` solo.
   No es un cambio intencional; confírmalo con Wilber si te importa
   fijar 4.3 formalmente.
2. Abrir Godot → Importar → seleccionar la carpeta `FootballCareer/`.
3. F5 o botón de play para correr `Start.tscn` (pantalla inicial única).
4. Para exportar a Android: Proyecto → Exportar → añadir preset Android
   (requiere Android SDK + plantillas de exportación de Godot instaladas).

## Notas técnicas pendientes de decidir

- **Assets de sonido:** ya resuelto — `autoloads/Audio.gd` (UI con
  Kenney "Interface Sounds", sonidos reales de partido de Wilber en
  `assets/sound/*.mp3` con fallback a `.wav` procedurales, música con
  crossfade, ambiente de estadio con ducking).
- **Arte real (escudos, retratos, balones, kits):** ya resuelto —
  escudos procedurales v4, `Kit.gd` (camisetas titular/visitante),
  `BallDesign.gd`, `Avatar.gd` (caras de usuario y NPC, pack Kenney),
  `StadiumBg.gd` (fondo con público animado). Todo determinista por
  seed, sin depender de licencias de arte real.
- **Excel de importación:** si se reusa el pipeline de `mundo_import_plantilla.xlsx`,
  Godot no tiene `openpyxl` nativo — se puede exportar a CSV/JSON desde
  Python fuera del proyecto y luego importar ese JSON con `SaveManager`
  o un `WorldDataImporter.gd` separado. Sustituiría a `WorldFactory`
  como fuente de ligas/clubes/jugadores manteniendo su misma interfaz.
