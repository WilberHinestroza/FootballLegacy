# FootballLegacy — Roadmap (desde el 9-oct-2026)

Orden pensado en paquetes medianos. Primero lo que NO necesita
generaciones de PixelLab (la cancha 2D con fichas), así cuando haya
generaciones solo se cambia el "skin" de lo que ya funciona.

Reglas que aplican a todo: el `MatchEngine` no sabe nada de UI (la cancha
solo dibuja eventos); toda la matemática de éxito/fallo sigue en
`DecisionResolver`; cualquier campo nuevo en `PlayerData` = cambio de
esquema anunciado + migración.

---

## ★ LISTA PRIORIZADA (9-oct, tarde) — la que manda de acá en adelante

**ALCANCE CONGELADO (9-oct, noche — Wilber: "ya no agreguemos más nada
fuera de lo que ya hablamos, hasta terminarlo").** Nada entra a esta lista
hasta cerrarla; las ideas nuevas se anotan aparte para después.

Orden: primero lo que está ROTO o Wilber no ve aunque exista, después lo
que pidió explícitamente, después pulido, después ideas nuevas. Los
paquetes de más abajo quedan como historial.

### P0 · Arreglos (lo que falla o no se ve)
- [x] Peinados: en las animaciones (festejos, trofeo, lesión, cambio) se
      perdían → capas de cabeza superpuestas siguiendo la cabeza por cuadro
      (`tools/anim_head_track.py` → `data/AnimHeadOffsets.gd`).
- [x] Guayos: solo se veían en el cuerpo entero quieto → clase "botín" en
      las animaciones (`tools/anim_boots.py`), se tiñen con los guayos
      puestos en la cancha y en los festejos; los demás jugadores con
      botines de colores variados.
- [x] (9-oct) +8 peinados con más carácter (afro, calvo, flequillo, coleta, puntas, degradado, rizos largos, raya).
- [x] Peinados que en el busto se ven casi iguales (rapado / tupé / rulos /
      engominado / moño) → regenerar los más flojos con más contraste.
- [x] Balones: catálogo = los 16 de Wilber (Objetos de su PixelLab) y la
      pelota de la cancha 2D es el balón del partido.
- [x] Tienda en pestañas Estilo (Ropa/Accesorios/Guayos) / Consumibles.
- [x] Bug: "¡CAMPEÓN! tocá para continuar" no cerraba (contenedor hermano
      se comía el toque) + ventanita rediseñada.
- [x] Guayos: tarjeta de la Tienda con zoom a los pies (Avatar.build_feet).
- [x] Pecas: dibujadas a mano, puntitos (pixel_layers.py FRECKLES).
- [x] Nombres que se pisan en la cancha 2D (PitchView._draw_labels).
- [x] Plantilla: aclarar "4-5-1" (cómo forman hoy) vs chip del DT (preferida).

### P1 · Pedido explícito (editor, Tienda, botones)
- [x] Editor: narices (3), orejas grandes, rasgos (mandíbula, redonda,
      pecas, cejas, cicatriz) — categorías nuevas del editor.
- [x] Tienda: +7 prendas y +4 guayos (9 en total).
- [x] Trofeos: los 80 de Wilber + 16 premios reemplazan a TODOS (Trophy.W_ART).
- [x] Camisetas de Wilber (32) como diseños de kit (~70% de los clubes),
      recoloreadas, local≠visitante; tu jugador y la cancha VISTEN el diseño.
- [x] Trofeos re-mapeados por parecido real + 14 de liga nuevos (ninguno repetido).
- [x] Calendario estilo app (escudo del rival, jornada, local oscuro /
      visitante claro, ícono de competición, hoy azul).
- [x] Botones "de juego" (relieve + hundido) en TODO el juego, títulos de
      sección con barra dorada, paginador compacto.
- [x] Club: cabecera héroe + franja de números + vitrina con trofeos reales.
- [x] Marcas de guayos (Voltix/Aerion/Vulpex/Summit) como PATROCINIO
      (schema v32, BootDealEngine + BootOfferPanel): pagan, regalan modelos.
- [x] Cabecera héroe en Entrenar, Vida personal, Agente, Perfil; Torneos con tarjetas + trofeo.
- [x] Presentación oficial al fichar (PlayerPresentation) — firma y fichajes de mitad de temporada.
- [x] Previa: competición como titular; balones en grilla (desajuste por 16 en una fila).
- [x] Partido: sin popups de acierto/desacierto ni de tarjetas (árbitro viejo); convocatoria 11+9.
- [x] Festejo: pies apoyados en el césped, pelota a escala, sombras.
- [x] Cancha 2D: arco 0.26 con profundidad, vallas, banderines, césped a cuadros, jugadores de relleno.
- [x] Pantalla inicial (logo + estadio pixel), deslizadores con barra (antes solo la manija).
- [x] TU estado "no convocado": confianza por el piso + sin mérito para los
      9 → afuera de la lista (nunca en amistosos); sin minutos ni nota.
- [x] Detalle de liga en Torneos: cabecera héroe, pestañas píldora (Tabla/Fixture/Goles/Asist./Playoffs/Tarjetas), leyenda de colores.
- [x] Editor de apariencia: categorías con ícono = la pieza real de tu avatar.
- [x] Botones: rediseño de TODOS (Styles.USE_GAME_BUTTONS: relieve, sombra,
      estado presionado visible, íconos donde aporte).
- [x] Logos de marcas: patrocinadores (8, PixelLab) en ofertas/Carrera/vallas de la cancha; guayos en Carrera.
- [x] Podio en Premios y en la ceremonia de fin de temporada (ui/common/Podium.gd).

### P1b · Último pedido (9-oct, noche)
- [x] Logos: consumibles (6), medios FICTICIOS con logo (8, reemplazan MARCA/ESPN/AS… reales),
      televisora en el marcador (EN VIVO), patrocinadores (8), emblema de Fichajes.
- [x] Evolución del jugador con sentido y divertida (subidas visibles,
      hitos, picos por edad, elecciones de entrenamiento que importan).
- [x] Sistema RPG completo revisado (schema v33): nivel 1-50 + puntos, árbol de
      habilidades por posición (SkillTree) que cambia los minijuegos, forma 1-5,
      intensidad de entrenamiento, panel de progreso animado post-partido.
- [x] Más animaciones (ui/common/Juice.gd): entrada escalonada de cada pantalla, dinero que
      cuenta, -€ flotante al comprar, HOY late en el calendario, botón de partido late, marcador
      salta con el gol, barras de XP/nivel, salidas animadas, habilidades que laten.
- [x] Vida fuera del fútbol animada: salidas al cine, con la novia, ver
      otros partidos, etc. + chicas para conocer (personajes pixel). HECHO v33:
      SocialLifeEngine + OutingScene + 8 chicas + 5 fondos (cine, cena, tribuna, fiesta, videojuegos).

### P2 · Interfaz / experiencia (pasada pantalla por pantalla)
- [x] Entrenar, Tienda, Fichajes, Perfil, Explorar: cabeceras héroe (Tienda la última).
- [x] Inicio en bloques (tarjeta tuya → próximo partido grande → semana →
      prensa → tabla resumida).
- [x] Pestañas iguales en todo el juego (Styles.tab, dorada = activa).
- [x] Paginador ◀ 1/3 ▶ más chico y agrupado (sigue ARRIBA: pedido explícito previo de Wilber).
- [x] Pantallas vacías con ícono pixel + frase (UiKit.empty_icon).
- [x] Números que se animan al cambiar (dinero en la barra; XP/nivel post-partido).

### P3 · Pendientes del juego (ya conversados)
- [x] Ediciones doradas de ropa por logros (GoldEditions, 5 prendas).
- [x] Ropa del patrocinador gratis mientras dure el contrato (SponsorEngine.GIFT).
- [x] Repetición de la tanda de penales en la cancha 2D.
- [x] Mapa de jugadas en partidos de selección.
- [x] Partidos de noche con reflectores en la cancha 2D.
- [x] Canas con la edad (desde los 31).
- [ ] DECISIÓN DE WILBER: VAR que anule goles de verdad (hoy cosmético).
- [ ] DECISIÓN DE WILBER: árbitro con personalidad (más/menos tarjetero).

- [x] (pedido 9-oct) Zoom de cámara al elegir la acción y al árbitro con la tarjeta.

### P4 · Minijuegos
- [x] Tiro libre en la cancha 2D (barrera; al palo = curvarla).
- [x] Cabezazo: tocar cuando cae la pelota (HeaderTiming + animación).
- [x] Penal desde el arco (penalty_save, también en la tanda).
- [x] Combos: regate ganado → remate más fácil 8'.
- [x] Dificultad visible (chips rival/cansancio/forma/ánimo/clima).
- [x] Cámara lenta de tus goles.
- [x] Momento de capitán: arenga en el entretiempo.

### P5 · Ideas de juego
- [x] Clásicos: presión según temple, XP ×1.5, prima, ánimo, tifo al arranque, cartel en la previa.
- [x] Apodo anunciado por la prensa + cantos de la hinchada con tu apodo al hacer gol.
- [x] Química con el plantel (pases con más zona; Relaciones; sube jugando y con videojuegos).
- [x] Lesión con decisión (parte médico: apurar = 55% de días + riesgo de recaída 4 partidos).
- [x] Contraoferta a ofertas de clubes (vencen a los 12 días; responden en 2: acepta / mitad / se retira).
- [x] Objetivos semanales (WeeklyGoalsEngine: 3/semana, premio dinero/XP/consumible, tarjeta en el Inicio).
- [x] Resumen de temporada tipo "Wrapped" (SeasonWrapped, al abrir la ceremonia).

### P6 · Ideas de arte con PixelLab
- [x] Retratos de NPC con expresión (capas feliz/enojado; el DT en el post-partido).
- [x] Ilustración por tipo de evento de temporada (12, assets/events).
- [x] Sala de trofeos pixel con tus copas (Perfil → Vitrina).
- [x] Hinchada que salta + bengalas en tus goles.
- [x] Charcos / nieve en la cancha 2D (procedural; el arte 3D de PixelLab no servía).
- [x] Retrato envejeciendo: arrugas desde los 33 + canas desde los 31.
- [x] Fondo de conferencia de prensa en la zona mixta.
- [x] Medallas pixel para los 22 rasgos (assets/medals, TraitBadge).
- [x] Cromos con marco por nivel en la Colección (procedural: los marcos de PixelLab salieron con el centro relleno).
- [x] Mapamundi pixel en Selecciones.

### Limitaciones conocidas
- En la cancha, de costado/espalda el peinado no se ve (el arte de
  peinados es de frente); de frente y en festejos sí.

## Paquete 1 — Cancha 2D v1 (sin generaciones) · HECHO 9-oct, a validar en el celular
- [x] Vista de cancha desde arriba (estilo de la captura de referencia:
      fichas con dorsal + nombre, balón, arco arriba).
- [x] Cada momento clave arranca mostrando la jugada armada (vos,
      compañeros, rivales, arquero).
- [x] Después de decidir, la cancha muestra cómo termina tu acción (pase
      que llega o interceptado, remate que entra o atajado, regate,
      quite...) y recién ahí sale el resultado/celebración.
- [x] Goles del rival con la jugada que los origina.
- [x] Fix: la pausa del motor esperando a la pantalla se medía en FRAMES
      (540 = 9 s a 60 Hz, solo 4,5 s en un celular a 120 Hz).
- [x] (extra, pedido 9-oct) Penal con el arco en 9 zonas + arquero
      (GoalAimGrid + DecisionResolver.aim_penalty_grid_multiplier, misma
      probabilidad de atajada que antes).

## Paquete 2 — Cancha interactiva (sin generaciones) · HECHO 9-oct, a validar en el celular
- [x] Elegir la acción SOBRE la cancha: tocar a un compañero = pase,
      tocar el arco = remate, tocar el espacio = conducir (el menú de
      siempre queda como alternativa).
- [x] Goles de compañeros también con su jugada.
- [x] Mapa de calor y mapa de pases en el resumen del partido (con tus
      jugadas reales) — "TUS JUGADAS EN LA CANCHA" (solo club; falta en
      el resumen de selección).
- [x] Clima visual en la cancha (lluvia, nieve, nublado) con el MISMO
      clima de la previa (MatchIcons.weather_for). El efecto en el juego ya
      existía (Match._context_mods). Pendiente: noche con focos.

## Paquete 3 — Pelota parada y VAR (sin generaciones) · HECHO 9-oct, a validar en el celular
- [x] Repetición del penal: la pelota va a la zona elegida y el arquero se
      tira. Bug real arreglado: el penal TUYO no emitía DECISION_RESULT
      (errarlo no avisaba nada). Goles de penal de la IA se ven como penal.
- [ ] Repetición de la TANDA de penales (todavía sin cancha).
- [x] Tiro libre / remates: la pelota va al palo que elegiste en el
      minijuego de apuntar (barrera ya dibujada en el tiro libre).
- [x] VAR con la línea de fuera de juego (~12% de los goles) — SOLO
      suspenso, siempre confirma. VAR que anule de verdad = decisión de
      balance pendiente de Wilber.
- [x] El árbitro (ficha) aparece en la cancha en inicio, entretiempo,
      final, tarjetas y cobro de penal — se reemplaza por el sprite en el
      Paquete 5.
- [x] Bug del Paquete 1 arreglado: una tarjeta nacida de tu propia jugada
      cancelaba la repetición.

## Paquete 4 — Personajes en la cancha (≈15-20 generaciones)
- [ ] Tu personaje (8 direcciones + correr) en vez de fichas, compañeros
      teñidos con el kit del club por código.
- [ ] Arquero (buzo + guantes) con estirada.
- [ ] Animaciones de pase, remate, regate y barrida.

## Paquete 5 — Árbitro y celebraciones (≈10-15 generaciones)
- [ ] Árbitro: pitido inicial, entretiempo, final, amarilla, roja.
- [ ] 6 celebraciones de gol animadas.

## Paquete 6 — Editor y Tienda (≈15 generaciones)
- [x] Peinados: moño, trenzas, rastas, engominado (9-oct).
- [x] Caras: bigote, candado, barba de 3 días, barba larga (9-oct;
      "sonrisa" quedó afuera).
- [x] Guayos: 5 modelos en la Tienda (slot acc_feet, zona de los pies).
- [ ] Ediciones de oro (desbloqueo por logros) y ropa de patrocinador
      (gratis con contrato de la marca).
- [ ] Diseños de camiseta (rayas, mitades, banda) + logo del patrocinador.

## Paquete 7 — Vida y carrera (≈10 generaciones)
- [ ] Vivienda y coche en pixel art (Estilo de vida).
- [ ] Canas con la edad (solo tinte, gratis).
- [ ] Ceremonias: levantar el trofeo, Balón de Oro.
- [ ] DT en la banda (festeja / se enoja), camilla en lesiones.


## Pedido 9-oct (después del Tier 1) — orden acordado
1. [x] Árbitros: 3 árbitros (negro, amarillo flúor, turquesa) con
       animaciones (pitazo, amarilla, roja, correr ×4) en la cancha, uno
       fijo por partido (data/Referee.gd, tools/fetch_referees.py).
2. [x] Escudos MODERNOS y MODULARES — en el juego desde 9-oct 07:20
       (Crest.PIXEL_SET, false = volver a los anteriores). Bisel + aro
       interior de acento + sombra de emblema + placa si hay patrón.
       Antes:
       10 siluetas modernas dibujadas por código (tools/crest_shapes.py)
       + 12 emblemas PixelLab (art_src/pixellab/crests/emblems). Falta
       integrarlo en Crest.gd cuando Wilber apruebe el estilo. las siluetas de prueba (heater,
       redondo, hexágono...) NO le gustaron. Quiere siluetas "de la
       actualidad" + diseños + objetos (emblemas) como piezas que se
       combinan. Revisar el arte que Wilber ya hizo (balones, diseños de
       camisetas y de escudos) y usarlo como base para hacerlo modular.
3. [x] Trofeos faltantes: liga de Ucrania, máximo goleador, copa
       continental genérica, copa de selecciones genérica — 55/55 ligas y
       todos los premios con arte propio (tools/TrophyCoverageProbe).
4. [x] Animaciones del jugador (PixelLab sobre el personaje base, teñidas
       por cuadro con piel/pelo/kit — tools/anim_layers.py,
       Avatar.build_anim): 6 celebraciones de gol (GoalCelebration),
       levantar trofeo (MatchSummary), Balón de Oro (SeasonCeremony),
       lesión y cambio (cartas de evento del partido). Limitación: el
       peinado/accesorios no van en las animaciones.
5. [x] Minijuegos interactivos EN LA CANCHA (9-oct, instalado 08:55):
       remate (arrastrar lejos del arquero), pase (tocar al compañero con la
       línea libre), regate (deslizar al lado contrario cuando entra),
       defensa (tocar cuando la pelota se separa del pie), arquero
       (deslizar al palo / salir a cortar). ui/match/PitchMinigame.gd +
       DecisionResolver.pitch_*_precision (misma escala que la barra).
       Tiro libre, cabezazo y penal mantienen sus minijuegos. A ajustar
       con el feedback de Wilber jugando.: que uno pueda
       INTERFERIR en la acción mientras pasa (no solo elegir y tocar una
       barra).
       Propuesta de diseño (a validar con Wilber):
       - La jugada se juega EN la cancha 2D en cámara lenta, y vos
         intervenís mientras pasa — el resultado de tu intervención es
         la `precision` que ya usa DecisionResolver (el balance NO cambia,
         solo cambia CÓMO se mide qué tan bien lo hiciste).
       - Remate: el arquero se mueve; arrastrás el dedo hacia el arco y
         soltás — cuenta el lugar (lejos del arquero) y el momento.
       - Pase: los rivales cierran líneas de pase en vivo; tocás al
         compañero cuando su línea está libre (marcada en verde).
       - Regate: el defensor viene de frente; deslizás izquierda/derecha
         justo cuando va a entrar (amague).
       - Quite / anticipo: el rival conduce; tocás cuando la pelota se le
         separa del pie (destello).
       - Arquero: el remate viene; deslizás hacia donde va la pelota.
       - Las barras/ritmo actuales quedan como respaldo (y para quien
         prefiera lo clásico, opción en Ajustes).

## Paquete 8 — Rediseño de lo procedural con PixelLab (generaciones: según alcance)
Ya es arte de Wilber (Gemini, Parte 92) y NO se reemplaza sin pedirlo:
10 balones, camisetas (silueta classic + 28 patrones), ~53 trofeos,
18 escudos. Candidatos reales:
- [ ] Escudos que siguen siendo procedurales (Crest.gd) — un set pixel
      art teñible por colores del club.
- [ ] Trofeos que caen al fallback procedural (familias sin arte propio).
- [ ] Fondo de estadio (StadiumBg, hoy procedural) en pixel art.
- [ ] Banderas de países en pixel art.
- [ ] Menús / UI: botones, marcos de tarjeta, iconos del Hub en el mismo
      estilo pixel (create_ui_asset de PixelLab).

## Ideas sueltas (sin paquete todavía)
- Química con compañeros: el que más te asiste/asistís gana conexión.
- Rival personal: el defensor que más te marca a lo largo de la carrera.
- Jugadas de lujo desbloqueables (rabona, chilena, sombrerito) como
  rasgos que agregan opciones al menú de decisión.
- Brazalete de capitán cuando la confianza del DT es muy alta.
- Carta de jugador estilo FUT con tu avatar pixel que evoluciona.

## Tanda nocturna 10-oct (pedido de Wilber antes de dormir) — HECHO
- [x] Trofeos v3: 133 rehechos con PixelLab a partir del nombre de cada
      liga/copa/torneo/premio (assets/trophies/v3, Trophy.V3_ART manda).
      MVP de temporada tenía trofeo vacío → regenerado.
- [x] Escudos sin repetirse: reparto por país de emblema+silueta
      (Crest._slot_for) + 17 emblemas nuevos (29 en total). Probe:
      tools/CrestUniqueProbe (55 ligas OK).
- [x] Carta de jugador estilo Ultimate (ui/common/UltimateCard.gd) en el
      Hub (compacta) y en el Perfil (grande, con las 6 stats).
- [x] Retiro: ceremonia de despedida (tifo, números, palabras del DT) y
      camiseta retirada si la carrera lo merece (LegacyEngine — sin
      cambio de esquema). Probe: tools/FarewellProbe.
- [x] Red social "Mundo": resultados reales de la jornada por las cuentas
      de los clubes (con marcador), la liga con la punta, medios con
      goleadores/Balón de Oro, rumores, selecciones y tendencias
      (WorldPulseEngine). Periodistas con nombres reales → ficticios.
- [x] Marcador de transmisión por canal (MediaOutlets.BROADCAST) + franja
      del torneo con su trofeo y color.
- [x] Arcos 3D (postes que suben, travesaño, red en caja, sombra) y 6
      cortes de césped × 4 tonos por estadio (PitchView.grass_for).
- [x] 4 celebraciones nuevas (pistolas, saludo, aplauso, grito) y 2
      compañeros que se suman al festejo con tu kit.
- [x] Ropa: 5 conjuntos (camisa y chinos, gabardina, parka, blazer,
      cortavientos), zapatos de salir (zapatillas, mocasines, botas
      chelsea), guayos plata/lava, bufanda, boina, lentes redondos.

## Pendiente de la lista de Wilber
- [ ] 3 tipos de cámara (TV lateral / isométrica) — requiere generalizar
      la proyección _p y la orientación de sprites; dejado para una
      tanda con él despierto para elegir.
- [ ] VAR real vs cosmético y personalidad del árbitro (decisión suya).
- [x] (10-oct) Logos de los entrenamientos (Físico, Técnica, Mental,
      Equilibrado) en pixel art, hoy son íconos genéricos.
- [x] (10-oct) Siguen saliendo trofeos VIEJOS (Vitrina: sala de trofeos y
      honores individuales — Bota de Oro, Podio del Balón de Oro, 11
      ideal). Encontrar qué camino no pasa por Trophy.V3_ART y BORRAR el
      arte viejo que ya no se usa para que no haya conflictos.
- [x] (10-oct) Tienda separada por tipo: camisas, chaquetas, pantalones,
      zapatos (de calle), accesorios y guayos/botines aparte. Hoy los
      zapatos de salir comparten el slot de los guayos (acc_feet): hay que
      separarlos (implica revisar el slot y la capa de dibujo).
- [x] (10-oct, visto en captura) Honores individuales: "Eredivisie" se
      corta letra por letra ("Eredivisi / e"); tarjeta "Físico" de
      Entrenamiento con el texto montado/cortado.

## Próximo paquete — Minijuegos y jugabilidad (10-oct, ideas aprobadas por Wilber; DESPUÉS de la lista priorizada)
Hoy: 5 minijuegos de cancha (PitchMinigame: pass/dribble/defend/keeper/
sweep) + grilla de penal, barra de tiro y cabezazo, para ~25 tipos de
jugada → muchas se sienten iguales. Balance SIEMPRE en DecisionResolver.
A. Gestos distintos
- [ ] 1. Remate con potencia (mantener) y efecto (deslizar mientras carga).
- [ ] 2. Regate con combos de 2-3 gestos; jugadas de lujo (rabona,
        sombrerito, caño) desbloqueables como habilidades.
- [ ] 3. Pase al hueco dibujado (arrastrar a dónde cae la pelota).
- [ ] 4. Arquero con reflejos: ver volar la pelota, deslizar alto/bajo.
- [ ] 5. Centro (elegir zona del área) + cabezazo encadenados.
B. Fluidez
- [ ] 6. Jugadas encadenadas (un buen regate abre remate/asistencia).
- [ ] 7. Elegir ANTES de la jugada (conducir / pasar rápido / aguantar).
- [ ] 8. Fatiga y presión en el gesto (zona verde más chica al 85',
        barra que tiembla en finales; Temple lo calma).
- [ ] 9. Juego ambiental en la cancha entre tus momentos.
C. Por posición
- [ ] 10. Defensor: anticipación (cortar la línea de pase).
- [ ] 11. Mediocampista: visión (encontrar al libre) y cambio de frente.
- [ ] 12. Delantero: desmarque antes de recibir.
D. Recompensa
- [ ] 13. Calificación por gesto (Perfecto/Bueno/Flojo), racha y XP.
- [ ] 14. Retos del DT antes del partido.
- [ ] 15. Modo práctica en Entrenamiento (jugar el minijuego del foco).
Orden sugerido: 1, 6, 13.

## Tanda 10-oct (día) — HECHO, verificado en captura real
- [x] Inmersión (engine/career/ImmersionEngine.gd, sin cambio de esquema;
      probe tools/ImmersionProbe, 17 chequeos):
      vestuario tras el partido (reemplaza "EL ENTRENADOR TE DICE"), rival
      personal (PreMatch "DUELO PERSONAL", Perfil, DM y posts), mensaje de
      casa + familia en la tribuna en partidos clave, pancartas/silbidos al
      arrancar, carta especial (EN RACHA / PREMIO / ÍCONO) y semana de
      clásico (Hub + red social). Historial del rival = season["nemesis_log"]
      (solo la temporada en curso).
- [x] Trofeos: arte ÚNICO v3. Retirados los 3 sistemas viejos (capas,
      fixed, w) a art_src/_retired/trophies. Trophy.for_entry = única
      puerta para un título ganado. Probe: tools/TrophyV3Probe (151 ids).
- [x] Tienda por prendas: Camisas / Chaquetas / Pantalones / Zapatos /
      Accesorios / Guayos. Cada conjunto partido en arriba + pantalón
      (tools/split_outfits.py → assets/pixelplayer/top|bottom), sin
      generaciones. Zapatos de calle en slot propio (acc_shoes): guayos con
      el kit, zapatos con ropa de calle. Conjuntos enteros de guardados
      viejos siguen valiendo (Avatar.owns). Probe: tools/WardrobeSplitProbe.
- [x] Logos de entrenamiento en pixel art (4) + tarjeta que crece con el texto.
- [x] Cancha: arco con alto a escala del jugador, áreas ensanchadas
      alrededor del arco, cancha a todo el ancho con el frente pasándose de
      la pantalla (OVERSCAN 1.10, TILT_FAR 0.78), flecha sobre tu jugador,
      árbitro sin cartel, banco y torres de luz dentro de pantalla, tope de
      alto 360 → 460.

## Pendiente real (al 10-oct)
- [x] DECISIÓN DE WILBER — esquema v34: clubes donde jugaste (silbidos al
      volver a tu ex club) + historial del rival de toda la carrera.
- [x] DECISIÓN DE WILBER — VAR real vs cosmético; árbitro con personalidad.
- [x] DECISIÓN DE WILBER — regenerar la celebración "pistolas".
- [ ] Jugadores de espalda y de costado en la cancha (hoy todos de frente):
      requiere generar cada animación en otras direcciones con PixelLab. Es
      el primer paso obligado de la cámara TV lateral.
- [ ] 3 cámaras (TV lateral / isométrica).
- [ ] Lista visual de la cancha: sombras según la hora, tribuna viva,
      marcas en el pasto, vida de los jugadores sin pelota, DT y banco en la
      banda, detalles de transmisión, estadios distintos.
- [ ] Paquete de minijuegos y jugabilidad (15 puntos, ver arriba).
- [ ] Acordado antes: juego ambiental en la cancha, cámara que sigue la
      pelota en repeticiones, momentos encadenados, minijuegos por posición,
      repetición desde otro ángulo, mapa de jugadas en selección.
- [ ] Probes viejas a poner al día: PixelAvatarProbe (referencias del 9-oct
      y espera schema 31), CrestUniqueProbe/BootDealProbe (necesitan ventana).
- NOTA: Paquetes 4-7 de más arriba figuran sin marcar pero están hechos
  (personajes, arquero, árbitro, celebraciones, ediciones doradas, vivienda
  y coche, canas, ceremonias, DT en la banda).

## Tanda 10-oct (tarde) — HECHO
- [x] Esquema v34 (aprobado por Wilber): player.former_clubs, nemesis_log,
      achievements, mastery. Migración v33→v34 en SaveManager.
- [x] Ex clubes: la hinchada te recibe según cómo te fuiste (traidor /
      ídolo / ex). Historial del rival personal de TODA la carrera.
- [x] VAR REAL: el motor puede anular goles de jugada (≈12% se revisan,
      30% de esas se anulan; nunca penales). Evento GOAL_DISALLOWED.
      Balance en DecisionResolver.var_review. Probe: tools/VarRefereeProbe.
- [x] Árbitro con personalidad (5 estilos por nombre: deja jugar,
      equilibrado, estricto, tarjetero, amigo del VAR) — se ve en la previa.
- [x] Celebraciones: pistolas regenerada + 7 nuevas (brazos cruzados, dedos
      al cielo, salto y brazos abajo, saludo surfero, meditación, brazos
      abiertos, robot). Sin nombres de jugadores reales. FESTEJO DE FIRMA
      elegible en Mi Perfil → RPG.
- [x] Animaciones de situación: llamada, pensar, sorpresa, himno, lamento,
      firma, puño — en evento de temporada, convocatoria, oferta de
      patrocinio, mejora de sueldo y pantalla de Patrocinios.
- [x] Pantalla PATROCINIOS en Carrera (scenes/Sponsors): contrato principal,
      contrato de guayos, ofertas pendientes y catálogo de marcas.
- [x] Entrenamiento: la pantalla no tenía scroll y se rompía al crecer las
      tarjetas → ahora con ScrollContainer.
- [x] Rasgos: 22 → 38 (16 nuevos de historia de carrera y de atributo, con
      medalla pixel). Menú nuevo: slots a la vista, resumen de lo que
      suman, filtro por 7 categorías.
- [x] RPG ampliado (engine/career/CareerRpgEngine.gd) + pestaña RPG en Mi
      Perfil: rango, arquetipo, 3 maestrías (suben jugando, +0,4% por
      nivel), 30 logros con XP, festejo de firma. Probe: tools/RpgProbe.
- [x] PROGRESIÓN auditada y reajustada (tools/ProgressionAuditProbe):
      antes el que solo jugaba llegaba a 72 a los 32 (potencial 84), el
      dedicado al tope a los 22 y nadie bajaba de veterano. Ahora: 79 a los
      29 / tope a los 24 / declive desde los 32. Perillas en
      PlayerDevelopment (MATCH_XP_BASE, age_xp_mult, near_cap_mult,
      weekly_decline_chance).
- NOTA: tools/career_sim.gd NO sirve para medir progresión (no aplica la XP
  de partido ni los entrenos del juego real). Usar ProgressionAuditProbe.
- NOTA: pitch_idle y pitch_run YA existen en 8 direcciones; lo que falta
  de espalda/costado son pase, remate y barrida.

## Tanda 10-oct (noche, Wilber ausente: "avanzá todo lo que puedas") — HECHO
- [x] Mi Perfil: RASGOS en su propia pestaña (6 pestañas en 2 filas de 3).
      Bug del RPG a ancho de celular: etiquetas con ajuste de línea dentro
      de una fila se partían letra por letra ("Nivel 3 / 10" en vertical).
      RpgProbe ahora corre a 432x936 y falla si pasa de nuevo.
- [x] Ícono pixel de Patrocinios (assets/icons_px/sponsors.png).
- [x] Paquete de minijuegos (parte):
      #1  Remate en 2 pasos: apuntar en la cancha + POTENCIA manteniendo
          apretado (DecisionResolver.shot_power_zone / shot_power_precision).
      #6  Jugada ENCADENADA: un regate ganado puede dejarte definir vos en
          el mismo momento (DecisionResolver.CHAIN_*; reemplaza el sorteo
          del compañero, no suma goles — tools/ChainProbe).
      #8  Presión del momento: estamina en vivo < 45% y finales/eliminatorias
          achican (o agrandan con Temple 75+) la zona.
      #13 Calificación del gesto (Perfecto/Bien/Regular/Flojo), racha y XP
          extra (ProgressionEngine.gesture_xp, tope 60).
      #14 Reto del DT por partido (CoachChallengeEngine): +3 confianza y
          +25 XP si se cumple.
- [x] Minijuegos más claros: el panel muestra solo lo que cada uno usa (la
      barra ya no aparece mientras apuntás o gambeteás), el botón dice qué
      hacer, textos más cortos y grandes, y carteles sobre la cancha
      ("¡DESLIZÁ!" con flecha, "¡AHORA!", "LIBRE"/"MARCADO").
- [x] Zoom con dos dedos en la cancha (PitchView._pinch_input).
- [x] Camisetas que se confundían: Kit.colors_clash + alt_color_against (la
      regla vieja dejaba pasar verde oscuro vs verde).

## Pendiente real (actualizado)
- [ ] Minijuegos que faltan del paquete: #2 regate con combos y jugadas de
      lujo, #3 pase al hueco (ya se puede arrastrar; falta premiarlo), #4
      arquero con reflejos alto/bajo, #5 centro + cabezazo, #7 elegir antes
      de la jugada, #9 juego ambiental, #10-12 por posición, #15 modo práctica.
- [ ] Cámaras TV lateral / isométrica; pase, remate y barrida de espalda y
      de costado (idle y correr ya están en 8 direcciones).
- [ ] Lista visual de la cancha (sombras, tribuna viva, estadios distintos).
- [ ] A REVISAR CON WILBER: en la prueba sintética (delantero de 74 siempre
      titular, partidos simulados) salen ~3,8 goles por partido y ~1,2 del
      usuario. Es previo a los cambios de hoy; confirmar si en el juego real
      se siente alto antes de tocar el balance.
- [ ] Probar en el celular: zoom con dos dedos, potencia del remate y
      comodidad de los gestos (solo verificado en PC).

## Tanda 10-oct (tarde-noche 2) — HECHO, verificado en captura real y con pruebas
- **Números realistas por partido** (`tools/MatchNumbersProbe`, 150 partidos por caso): 2,2-2,8 goles,
  delantero 0,17-0,68 goles según nivel y manos, volante 0,11 G / 0,27 A, nota 6,2-7,8, ~4 amarillas,
  ~0,17 rojas. En un REMATE el toque limpio ya no es gol seguro (`DecisionResolver._out_finish`).
- **Cancha completa y grande** (`PitchView`): mundo y 0..2 (dos arcos), `WORLD_SCALE 1.7` (se ve una
  parte, la cámara sigue la jugada), 22 jugadores en 4-4-2, radar en la esquina, botón "Ver todo".
  Un dedo mueve la cámara, dos dedos acercan/alejan. Tres cámaras (arco / tv / iso).
- **Jugadas por zona** (`PitchPlays.ZONES`): defensa y arquero en tu mitad (`flip`), armado desde el
  medio (`stretch`), definición arriba. Las jugadas siguen escritas en coordenadas "de escena".
- **Estadio vivo**: ola, banderas, flashes, vallas LED, banderines, banco y DT, sombras de nubes,
  papelitos en el gol. **Jueces de línea** que siguen la jugada y levantan el banderín.
- **Fuera de juego**: el gol anulado por VAR se muestra como offside; un pase filtrado / pared que
  falla puede verse como fuera de juego (solo relato visual, el resultado ya lo decidió el motor).
- **Paredes** (`DecisionResolver.COMBO_*`, `PitchMinigame._wall`): 1-2 toques previos antes del pase final.
- **Rebote del arquero** (`REBOUND_CHANCE 0.22`): remate limpio atajado → definís de primera.
- **Cambios animados** (`PitchPlays.sub_scene`), **estrella** sobre tu jugador.
- **IA de posición** (`PitchView._extras_ai`): los que no participan acompañan la pelota; solo visual.
- **Animaciones nuevas de cancha**: entrada, cabezazo, caída, regate, volea, chilena, cuerpeo, protesta
  (`tools/pitch_sprites.py`; `PitchPlays._with_action_anims` las reparte).
- Bug corregido: los jugadores CORRIENDO llevaban la camiseta sin teñir (`fix_white_shirts`).

### Pendiente de esta tanda
- [ ] Probar TODO esto en el celular (el último APK no se pudo instalar: el teléfono no estaba conectado).
- [ ] IA "de verdad" para arquero y defensas dentro de la jugada (hoy la mueve el libreto de la jugada).
- [ ] Con la cámara muy alejada los nombres quedan chicos.
- [ ] Pase / remate / barrida y los gestos nuevos solo existen mirando al arco (en tv/iso se ven de espalda).

## Tanda 10-oct (noche 3) — HECHO
- Árbol de habilidades extendido (`data/SkillTree.gd`): ramas de puesto con 6 escalones (`EXTRA`),
  ramas comunes Físico / Liderazgo / CARRERA (`COMMON`); la de Carrera pide hitos reales (`req`).
  Sin cambio de esquema. Entrada fija al árbol en Mi Perfil → RPG. `tools/SkillTreeProbe`.
- Jueces de línea con arte de PixelLab (`assets/referee/linesman`, personaje árbitro "amarillo").
- IA visual dentro de la jugada (`PitchView._scene_ai`): arquero, defensas y compañeros.

## PARTIDO EN VIVO (10-oct noche, aprobado por Wilber: "procede")
Reemplaza el menú de decisiones por "oportunidades" que se juegan con el gesto. Wilber maneja solo
a su jugador; el motor sigue decidiendo el resultado con la precisión del gesto.
- **Etapa 1 — HECHA** (`PitchMinigame` modo "live", `Match._start_live/_on_live_done`,
  `DecisionResolver` bloque "OPORTUNIDAD EN VIVO", `tools/LivePlayProbe`):
  - Ataque: tocar a un compañero = pase · deslizar hacia el arco = remate (largo = fuerza) ·
    deslizar al costado = regate. Un rival te presiona: si tardás, la perdés.
  - Defensa: tocar = quite de pie · deslizar = barrida (más margen; si falla es falta y puede ser
    tarjeta: `SLIDE_*`, `MatchEngine._maybe_slide_foul`).
  - Fuera de juego real: el compañero que tira la diagonal puede quedar adelantado (`OFFSIDE_PRECISION`).
  - Solo valen los gestos de las opciones que ofreció el motor (así no cambian los números por partido).
  - Lo que no tiene versión en vivo (pelota parada, centros que te llegan, arquero) arranca su
    minijuego directo, sin menú. Ajustes → se puede volver al sistema por decisiones.
- **Etapa 2 — HECHA** (`DecisionResolver` "LA JUGADA CONTINÚA", bucle en `MatchEngine` tras
  `_apply_decision_result`): hasta 4 intervenciones seguidas. Regla de Wilber: atacando la jugada
  sigue mientras salga bien (termina si te la roban / se pierde / sale / remate); defendiendo sigue
  mientras el rival tenga la pelota (te pasaron → otra chance de frenarlo; termina con gol, afuera,
  robo o atajada). Medido: 2,4-3,0 goles por partido, delantero 0,21-0,75.
- Pase SIN ayudas (pedido de Wilber): ya no se muestra LIBRE / MARCADO / ADELANTADO ni la línea
  del fuera de juego; solo un aro neutro sobre a quién se le puede pasar.
- Bug corregido: la tribuna / familia y el tifo del clásico tapaban la jugada (salían 1,7 s después
  del saque). Ahora se muestran y terminan ANTES de que arranque el partido (`_pre_kickoff_show`).
- [ ] **Etapa 3**: IA completa de compañeros y rivales según atributos durante toda la oportunidad.
- [ ] Faltas que te hacen a vos, y tiro libre / penal nacidos de la jugada en vivo.

## Tanda 10-oct (noche 4) — HECHO
- **Ataque "congelado"** (pedido de Wilber): todo quieto hasta que hacés el gesto; sin reloj de presión.
  El regate ya no es por tiempo sino por espacio (`DecisionResolver.live_dribble_precision`).
- **Desmarque** (`PitchMinigame` fase "run", `RUN_SECS`, `run_speed`, `receive_difficulty_mod`): cuando
  la jugada sigue tras un pase tuyo, arrastrás el dedo y tu jugador corre a SU velocidad mientras los
  rivales lo siguen; recibir libre hace más fácil lo que viene, recibir marcado más difícil.
- **Juego ambiental** (`PitchView.setup_ambient`, `Match._show_ambient`): entre jugadas, y siempre
  que estás en el banco, la cancha muestra el partido andando (los 22, la pelota circulando según la
  posesión real). Es decorado: goles, tarjetas y jugadas siguen viniendo del motor.
- **Arcos del mismo tamaño** en la cámara detrás del arco: perspectiva simétrica (`_depth`, `_gy`).
- **Zoom acotado**: lo más lejos = la cancha entera; lo más cerca = `ZOOM_MAX 1.5`; la vista no se
  sale de la cancha (`_clamp_focus`).
- **Objetos de estadio de PixelLab** (`assets/stadium/`, `PitchView._draw_props/_draw_stand_tiles`):
  bancos, camarógrafos, fotógrafos, alcanzapelotas, guardias, torres, barra con bombo, tribunas llenas.
- El balón gira al rodar. Pase sin ayudas. Tribuna/familia antes del saque.
- `MatchEngine.hold` (gancho de pruebas) + `tools/AmbientProbe`.

### Pendiente
- [ ] Etapa 3: IA de compañeros y rivales por atributos durante toda la jugada.
- [ ] Faltas que te hacen, y tiro libre / penal nacidos de la jugada.
- [ ] Más arte de PixelLab: animar los objetos (camarógrafo, barra), marcador, túnel, camilla.
- [ ] Física de la pelota (pique, efecto) y transiciones entre animaciones de los jugadores.
- [ ] La cancha entera ("Ver todo") se ve ovalada por la perspectiva simétrica: revisar con Wilber.

## Tanda 10-oct (noche 5) — HECHO
- Bug: en el banco aparecías igual en el pitazo de inicio / entretiempo / final (`whistle_scene` + `Match._ctx_now`).
- Bug: el arquero se estiraba para el lado contrario al que se movía en TU arco (el lado ahora sale de la pantalla).
- La pelota ya no "atraviesa": se dibuja con profundidad (`_draw_ball`) y el juego ambiental solo pasa por líneas libres.
- Conducción: la pelota va adelante de quien la lleva y la va tocando (`_carry_offset`).
- Física: pase por el piso se frena, pelota por el aire da un pique.
- Falta a favor (`FOUL_WON_CHANCE`): te bajan en un regate → tiro libre tuyo.
- Los 22 de la cancha son los titulares de verdad: cara, pelo y ritmo según su Velocidad (`PitchView.team_people`).

## Tanda 11-oct (madrugada) — HECHO
- Arquero visto de ESPALDAS en tu arco: atajada y estiradas "_n" de PixelLab (`gk_*_n`, `PitchView._frames`).
- Festejo en la cancha tras el gol (`pitch_festejo`, paso "¡GOL!" de `PitchPlays._goal_steps`).
- IA por atributos en el juego ambiental (`_attr01`): Regate = aguanta más la pelota, Pase = pierde
  menos y se anima al pase largo, Fuerza del rival cercano = roba más, Velocidad = ritmo.
- `tools/KeeperBackProbe`.
### Pendiente
- [ ] Penal nacido de una falta en el área (el motor no tiene rama "penalty" en `_apply_decision_result`).
- [ ] IA por atributos DENTRO de tu jugada (hoy solo en el juego ambiental y en el desmarque).
- [ ] Animar objetos del estadio; marcador, túnel, camilla.

## Tanda 11-oct (mañana) — cámara detrás del arco
- **Cancha sin deformar**: `TILT_FAR = 1.0` (+ `FLAT_W`). La perspectiva simétrica hacía un óvalo y cerraba las líneas de tu mitad al revés. Ahora bandas rectas y los dos arcos idénticos.
- **Un solo pase ordenado por profundidad** en `PitchView._draw`: jugadores, objetos del estadio (`_prop_items`), jueces de línea y tu arco. Antes los objetos eran fondo (las líneas y todos los jugadores les pasaban por encima).
- Fotógrafos/camarógrafos corridos fuera de la línea de gol y del arco; vallas y tribuna de abajo un poco más lejos.
- `GOAL_W` 0.36 → 0.30 (arcos más chicos). Balón 0.42 → 0.32 del radio.
- **Penal por falta en el área**: `DecisionResolver.PENALTY_FROM_FOUL_CHANCE` (0.18 de las faltas que te hacen en un regate). Lo patea el usuario (`MatchEngine._user_takes_penalty`, extraído del penal ambiental); respeta `MAX_PENALTIES`. Números re-medidos: 2,5–3,1 goles/partido.
- **Atributos dentro de tu jugada**: los actores de la escena llevan `attrs`; en `PitchView._scene_ai` la Velocidad escala cuánto cierra el defensor y cuánto achica el arquero, y Regate/Velocidad cuánto se ofrece el compañero (siempre dentro de `SCENE_AI_MAX`, no cambia el balance).
- **Conducción con balón (PixelLab, 8 direcciones)**: `pitch_drib_<dir>` (fuente `art_src/pixellab/player_full/pitch_conduccion`, grupo 73eef812). `PitchView._draw` la usa en vez de `run_` para quien lleva la pelota (`_ball_follow` en jugadas, `_amb_holder` en el juego ambiental).
- **Objetos animados (PixelLab)**: `assets/stadium/<nombre>_a0..8.png` (camarógrafo, barra, alcanzapelotas) vía `PitchView._prop_frames/_prop_now`; nuevos `scoreboard` (con `score_text` que pone `Match._refresh_score`), `tunnel` y `medics`. Prueba: `tools/StadiumPropsProbe`.
- **Bug de espejado**: los objetos y el juez de línea espejados se dibujaban corridos un cuerpo a la derecha (el juez de la banda derecha quedaba fuera de cuadro). Ancho negativo sin sumar el ancho a la posición.
- Cámara: el foco ahora llega hasta los bancos/túnel (x ±0.17) y un poco más arriba (marcador).
- **Gestos con dirección (PixelLab)**: `pitch_{remate,pase,barrida}_{s,e,w}` (fuente `pitch_<gesto>_dir`, oeste = espejo). `PitchView._begin_step` guarda `act_dir` (hacia dónde va la pelota / el que barre, en pantalla) y `_frames` elige la variante. La barrida lateral de PixelLab sale de cabeza (2 tomas): los cuadros en el piso se espejan para que vaya con los pies adelante.
- **Camilla en las lesiones**: `PitchPlays.injury_scene` + paso de guion `"stretcher"` en `PitchView` (`_str_*`, arte `medics_a0..8`); `Match._play_injury_replay` la muestra antes del aviso (mismo patrón que las tarjetas). Prueba: `tools/InjuryProbe`.
- **Gestos en 8 direcciones**: remate y pase suman `_ne/_nw/_se/_sw` (`_act_dir`); la barrida cae a la más parecida.
- **Juego ambiental**: el que pasa hace el gesto hacia el compañero (pelotazo largo = remate), también en carrera.
- **Juego organizado** (lo de "organizar el juego" = gameplay de partido): los dos equipos usaban el mismo 4-4-2 espejado y las líneas caían una sobre otra (parejas encimadas: 112 de 112 cuadros en `AmbientProbe`; ahora 0 de 108). Dibujos intercalados por equipo en `_add_extras`; en `_extras_ai` el que tiene la pelota se abre y adelanta, el que defiende se cierra y retrocede, UNO sale a presionar y nadie se para encima de otro.
- **Nadie se teletransporta**: la duración de cada paso de una jugada se pensó para la cancha chica; con la cancha 1,7× los picos medían 25–47 cuerpos/s. `PitchView.play` estira cada paso para que la carrera no pase de `RUN_MAX_BODIES` (6; gestos 1,6×; estiradas libres), curva más suave (`RUN_EASE`), y el corrimiento de `_scene_ai` entra/sale de a poco. Prueba: `tools/MotionProbe`.
- **Fuera de juego bien medido**: `PitchView.offside_line_for(id)` = penúltimo rival de TODA la cancha; los de relleno tiran la línea (`_line_hold`); paso `"line": "auto:<id>"`; la línea del VAR va en el último defensor (antes en los pies del goleador) y si el goleador no la pasa el anulado es "FALTA PREVIA". Prueba: `tools/OffsideProbe` (80 jugadas + 60 revisiones).
- **Arquero**: tope de velocidad también para él (`play`, factor 1,8), el vaivén al apuntar entra de a poco, y **pasos laterales** `gk_paso_{der,izq}[_n]` (PixelLab, `paso_lateral`) vía `PitchView._keeper_steps`. Prueba: `tools/KeeperStepsProbe`.
- **Una sola cámara**: el partido usa siempre "arco"; se quitaron el botón de cámara y la opción de Ajustes (el código de tv/iso queda en PitchView para las pruebas).
- **Pasos al ritmo del avance**: el cuadro de `run_`/`drib_` sale de la distancia recorrida en pantalla (`STRIDE_PX`), no de un reloj fijo — las piernas ya no patinan.
- `tools/InjuryMatchProbe`: lesión dentro de un partido real (camilla → aviso → cambio).
- **Giros**: `vdir` por actor — al cambiar de dirección pasa por las intermedias (45° cada `TURN_STEP` = 0,05 s, por el lado corto). Vale para carrera, conducción y parado.
- Relleno vs. jugada: corrimiento final DE COSTADO si un jugador de relleno cae a menos de 0,09 de uno de la jugada. Medido en `OffsideProbe`: 1 caso en 80 jugadas (ya era 1 antes: lo "cargado" de la captura eran los propios actores de la jugada).
- **Respiración parado**: por código en `PitchView._draw` (torso+cabeza bajan 1 px cada `BREATH_SECS`, desfasado por jugador). La plantilla `breathing-idle` de PixelLab se descartó: redibuja al personaje (salía calvo) — fuente movida a `art_src/pixellab/_descartado/`.
- **Barrida en diagonales**: `pitch_barrida_{ne,nw,se,sw}` (mismo espejado de los cuadros en el piso).

## Tanda 11-oct (tarde) — vuelta a decisiones (Wilber lo probó en el teléfono y no le gustó el modo en vivo)
- **Partido por DECISIONES otra vez**: `Preferences.live_play = false` fijo, sin opción en Ajustes. El modo en vivo queda ESTACIONADO (código y `LivePlayProbe` siguen) hasta armarlo aparte.
- **Solo narración entre jugadas**: `Match.AMBIENT_PITCH = false` (los 22 moviéndose solos no coincidían con el relato). La cancha aparece GRANDE (`_fit_pitch`, guarda el relato) y con el partido detenido para: goles, ocasiones claras, penales, amarillas, rojas, lesiones y tus jugadas.
- **Ocasiones claras**: `MatchEngine.CLEAR_CHANCE_SHARE` (0.5 de los remates al arco sin gol) → evento AMBIENT `clear_chance` con pausa; `PitchPlays.clear_chance`; `Match._play_chance_replay`.
- **Pase (botones)**: muestra a quién podés pasarle (aros neutros, sin semáforo libre/marcado), tocás o arrastrás, después la barra.
- **Ritmo**: movimiento casi parejo (`RUN_EASE_MIX`), tope de carrera 7,5; caché de animaciones que no existen (`_no_anim`). `tools/PerfProbe`.
- **Remates (Wilber: "siempre fallo")**: la puntería pedía 0.40–0.80 de separación del arquero (al palo con el arquero en el medio da 0.56 → en jugadas difíciles no alcanzaba nunca) y quedar corto topaba en 0.70 < `CLEAN_HIT`. Ahora `SHOT_AIM_NEED_EASY/HARD` 0.25–0.52, quedarse corto resta en proporción, y la zona de fuerza es más ancha y lenta.
- **Caminos**: regate ganado → casi siempre elegís cómo terminar (`CHAIN_CHANCE` 0.85; rematar / pase / pase atrás); pase que sale → encarar / filtrar / probar de lejos (0.62); robo → salir corriendo / pase adelante / cambio de frente (`CONTINUE_WIN_BALL_CHANCE` 0.60). Medido: 2,5–3,0 goles/partido, delantero 0,25–0,87.
- **Post partido**: 4 pestañas — Vestuario (charla, destacada, progreso, logros) · Estadísticas (figura, tu partido, mapa, números) · Otros · Notas. `tools/SummaryTabsProbe`.
- **3 bugs del 11-oct (teléfono)** — prueba `tools/ThreeBugsProbe`:
  - "va al arco pero dice afuera": el punto de "afuera" era lado × (medio arco + 0.06) → con puntería hacia adentro caía DENTRO del arco. Ahora si apuntaste adentro y no entra es ATAJADA; "afuera" siempre pasa por fuera del palo.
  - "siempre la misma falta": el amonestado se dibujaba sin cara, la víctima era siempre el primero de la lista y el lugar fijo. Ahora `_person_named` / `_person_other`, lugar al azar, semilla propia por tarjeta (`_rng_mix`).
  - "la acción siguiente me pone en el lugar de siempre": `Match._last_user_world` → `ctx["user_at_world"]` → `PitchPlays.scene_for` corre toda la escena (costado exacto; altura ±0.1).

## Tanda 11-oct (noche) — pulido del partido por decisiones
- **La red reacciona al gol** (`PitchView._net_t/_net_x/_net_end`, malla que se hunde y vibra ~1,5 s) y la pelota entra hasta el fondo (`_goal_point` y = -0.034). Prueba `tools/NetProbe`.
- **La pelota sale cuando el pie le pega** (`_kick_wait`, `KICK_CONTACT`), **comba** en centros y remates (`_curve`, paso `"curve"`), estela corta cuando va rápido, y se **eleva** de verdad (sube más, se agranda, sombra chica y clara en el piso).
- **Goles con historia**: palo y adentro, al ángulo, abajo al palo; errados "¡EN EL PALO!" (`GOAL_POST_IN_SHARE`, `GOAL_TOP_CORNER_SHARE`, `MISS_POST_SHARE`). **La altura la elige el usuario con la fuerza**: principio de la zona verde = rasante, final = arriba (`ctx["shot_level"]`).
- **Jugadas por las dos bandas**: `PitchPlays.mirror_for` + `PitchView.scene_mirror` (espeja posiciones, pasos, minijuegos y toques juntos). El arrastre para apuntar es siempre "izquierda de la pantalla = palo de la izquierda".
- **Barra hablando de vos**: solo si sos ídolo (`ImmersionEngine.IDOL_*`) y no en cada partido (`LOVE_BANNER_SHARE` 0.4; en el clásico siempre).
- **Lesión**: carrito médico (PixelLab, `assets/stadium/medcart.png`); el jugador sube (paso `"hide"`) en vez de ser arrastrado.
- **Mercado**: filtros de posición / edad / valor y orden (`Transfers._passes_filters`); cada fichaje trae `age` y `value`. Prueba `tools/MarketFiltersProbe`. MEDIDO: 77 fichajes por temporada, **0 bombazos (85+)**, media más alta que se movió: 78 → el nivel "potente" casi nunca encuentra jugador (elige club al azar). PENDIENTE de aprobación de Wilber: arreglarlo necesita un cambio de esquema (v35) para no alterar la temporada en curso de las partidas existentes.
- IDEA de Wilber (sin hacer): las cámaras TV / isométrica para ver el partido desde el estadio cuando NO está convocado; hay que arreglar túneles y bancos en esas vistas.
- **Remate en 3 pasos**: apuntar → cómo le pegás (`DecisionResolver.STRIKES`: colocado / potente / con comba, cada uno con su trueque vía precisión) → potencia (que además elige la altura). `Match._start_strike_choice`. Prueba `tools/StrikeProbe`.
- **Volada alta del arquero** (`gk_volada[_n]`, PixelLab `volada_alta`): en pelotas altas al palo (`_arc >= 1.5`) vuela en diagonal (el arte es un salto recto; `PitchView` lo inclina). Prueba `tools/HighSaveProbe`.
- **Esquema v35** (`market_v2_from_day`, nivel slot; anunciado y confirmado): **BOMBAZOS** — `TransferMarketEngine._bombazos`: 2–4 figuras de los 36 clubes más fuertes cambian de equipo por temporada, a otro grande, por 1,15–1,60× su valor y cerca del cierre. Una carrera vieja conserva su temporada en curso idéntica (probado: 77 = 77 fichajes). Prueba `tools/SchemaV35Probe`.
- **Comba hacia adentro / hacia afuera** (`STRIKES["comba"]` / `["comba_fuera"]`): doblan para lados opuestos.
- **No convocado = desde la tribuna**: `Match._fit_pitch` usa la cámara isométrica; `PitchView._draw_surround_iso` le pone piso, tribunas con gente y vallas.
- **El palo y la segunda jugada**: si el motor deja la pelota viva (`rebound_mode`) puede ser por el poste ("¡SIGUE LA JUGADA!"); si no, la despeja un rival y termina.
- **Patada al ritmo de la pelota**: los golpes van a `KICK_FPS` 20 (antes 10): el pie llega a la pelota cuando sale.
- **Líneas de tiro al elegir el golpe**: `PitchView.set_shot_previews` dibuja la curva de cada golpe (blanca colocado, roja potente, azul comba adentro, naranja comba afuera), del color de su botón.
- **Cartel de cambio**: paso `"board"` → el cuarto árbitro levanta el cartel (rojo sale / verde entra).
- **Estadios**: `stand_kind` por estadio (popular de siempre / techo con reflectores / dos bandejas con palcos; arte PixelLab `stand_roof`, `stand_modern`) y **pancartas** por código en los colores del local (`_draw_banners`, frases genéricas). Prueba `tools/StadiumKindsProbe`. Descartado: `stand_terrace` (salió en perspectiva y con un arco de fútbol americano).
- **Segunda pelota**: un despeje tuyo que sale puede caerle al rival (`SECOND_BALL_CHANCE` 0.45) → seguís defendiendo desde ahí.
