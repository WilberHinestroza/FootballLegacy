# Football Career — Contexto persistente para Claude Code

## Quién soy y qué es esto

Wilber es el único desarrollador. El juego se llama **FootballLegacy**
(renombrado el 2026-09-05; la carpeta del repo sigue siendo
`FootballCareer` y el paquete Android `com.wilber.footballcareer` NO
cambió, para no perder partidas). Es un juego de fútbol para
Android hecho en **Godot 4.3 (GDScript)**, modo carrera **individual**
(un solo futbolista, no un club) — inspirado en World Soccer Champs
pero con el foco en la historia personal del jugador, no en gestionar
un equipo. Idioma de trabajo: español. Comunicación cálida y concisa.

Este proyecto es la "segunda vuelta" de un juego anterior de Wilber,
**Football Legacy** (Kotlin/Jetpack Compose/Room, carrera de club).
Los aprendizajes de ese proyecto — buenos y malos — están destilados
en las reglas de abajo. Football Legacy en sí NO es parte de este
repo; solo su conocimiento aplicado.

## Reglas no negociables (aprendidas "a las malas" en Football Legacy)

- **Fuente única de avance de tiempo.** Todo lo que dependa del paso
  de un día pasa por el Autoload `WorldTickEngine.advance_day()`.
  Ninguna pantalla (Hub, Training, Match) duplica esa lógica.
- **Cambio de esquema de guardado = aviso explícito.** Cualquier campo
  nuevo en `PlayerData`/`ClubData` (los Resources en `data/`) es un
  cambio de esquema. Anunciarlo ANTES de aplicarlo y añadir una
  migración real en `SaveManager._migrate_if_needed()`. Nunca
  silenciarlo ni asumir que da igual.
- **El `MatchEngine` no sabe nada de UI.** Solo emite `MatchEvent` vía
  señal; las escenas deciden cómo animarlo/sonorizarlo. No meter
  lógica de Sprites/Tweens/sonido dentro de `engine/match/`.
- **Balance centralizado.** Toda la matemática de éxito/fallo de un
  momento clave vive en `DecisionResolver.gd`. Nunca duplicar una
  fórmula de balance en otro archivo — ese fue un bug real en FL con
  `parseHexColor`.
- **`potential >= overall` siempre.** Invariante de `PlayerData`,
  validar en creación de personaje y en cualquier importador futuro.
- **XI: portero real + 10 de campo, usuario siempre presente.** Nunca
  elegir el equipo solo por overall — ver `MatchTeam._build_lineup()`.
- **Orden de posiciones consistente en toda la UI:** GK → DF → MF → ST.
- **Estado compartido entre pantallas vía Autoload, no parámetros de
  escena.** Ver `MatchState.gd` — evita el bug de instancias separadas
  que tuvieron con `hiltViewModel()` en Compose.
- **`CalendarUtils.season_start_year()` siempre**, nunca el año
  calendario crudo, o una temporada ago-mayo se parte en dos el 1 de
  enero.

## Estilo de trabajo

- Explicar la causa raíz de cada bug antes de aplicar el fix, no solo
  parchar a ciegas.
- Corregir bugs antes de añadir features nuevas.
- GDScript: usar `var x: Tipo = expr` explícito (no `:=`) cuando la
  expresión venga de una función builtin "Variant-typed" como `abs()`,
  `min()`, `max()`, o de un ternario — Godot 4.3 puede tratar la
  advertencia de tipo inferido como error. Ya nos pasó una vez en
  `Match.gd`.
- Godot 4.3 estable. minSdk objetivo Android: revisar plantillas de
  exportación instaladas antes de asumir versión.

## Estado actual (ver también README.md en la raíz)

- Fases 0-9 completas (motor + persistencia): creación de personaje con
  test de personalidad, prueba inicial + 5 ofertas de club, calendario
  de liga/copa real para las 55 ligas del juego, mundo vivo (resultados
  de IA deterministas, nunca simulados por adelantado ni guardados —
  `WorldExplorer` deja ver cualquier liga/copa en cualquier momento),
  entrenador con confianza, entrenamiento/desarrollo/lesiones, contratos
  + mercado de fichajes al vencer contrato, patrocinios, agente,
  vivienda/coche, objetivos de temporada, prensa y zona mixta.
  `SaveManager` va por `schema_version` **35** (v35, 3-nov: mercado v2 + memoria de carrera) — historial completo en
  su cabecera.
- Fase 10 (selección nacional, Mundial, eliminatorias, copas
  continentales) **completa** (13-sep): eliminatorias por confederación,
  convocatoria por mérito, Mundial de 48, 5 copas continentales,
  repechaje jugable, pantalla "Selecciones" con explorador por
  confederación, y "Colección" (vitrina de todas las carreras, en curso y
  retiradas, con "récords" cross-save desde la Parte 91).
- Parte 91 (13-sep): calendario de año de Mundial cerrado del todo
  (mínimo de días entre jornadas más chico solo en años de torneo),
  prensa no ligada a partido (racha del club/narrativa de tramo final),
  fatiga/lesión ahora se aplican también en partidos de SELECCIÓN (antes
  solo en los de club — jugar un Mundial no costaba nada de cara al
  club), récords cross-save en "Colección".
- `DebugDataFactory.gd` — borrado (13-sep): era una red de seguridad para
  abrir el Hub sin carrera activa desde el editor, no la usaba el flujo
  real.
- El proyecto declara Godot 4.3, pero el único motor instalado es
  **4.7.2** — al abrirlo con el editor puede reescribir
  `config/features` solo (visto durante el desarrollo). Confirmar con
  Wilber si importa fijar 4.3 formalmente.
- El README.md tiene el árbol de carpetas completo, la tabla de mapeo
  Football Legacy → Godot y el roadmap de fases con detalle — leerlo
  si hace falta más que lo que cabe aquí.

## Qué NO traer de Football Legacy

- Nada de Kotlin/Compose/Hilt/Room — es solo referencia conceptual.
- Nada de nombres/imágenes de futbolistas reales (sin licencia FIFPro,
  igual que en FL).
