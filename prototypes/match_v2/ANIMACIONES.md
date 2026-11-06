# Prototipo match_v2 — inventario de animaciones (16-oct-2026)

Arte en `assets/pixelplayer/anim/<nombre>/` (cuadros + máscara de tinte) y
`assets/referee/<id>/`. Convención de direcciones del jugador: norte = sin
sufijo, `_s` sur, `_e` este, `_w` oeste (espejo), a veces `_ne/_nw/_se/_sw`.
Arquero: sin sufijo = mirando al sur (el de arriba), `_n` = de espaldas.
Galería con render real: `tools/ProtoAnimGalleryProbe.tscn`.

## En uso
| Situación | Animación | Direcciones |
|---|---|---|
| Quieto / correr / conducir | `pitch_idle_*`, `pitch_run_*`, `pitch_drib_*` | 8 |
| Pase / remate / barrida (planchazo) | `pitch_pase*`, `pitch_remate*`, `pitch_barrida*` | N, S, E, O, diagonales |
| Entrada de pie | `pitch_entrada`, `_s`, `_e`, `_w` | 4 (**nuevo 16-oct**) |
| Cabezazo | `pitch_cabezazo` (N), `_e/_w` (palomita) | 3 (**nuevo**) |
| Regate / gambeta | `pitch_regate` (N), `_s` | 2 (**nuevo `_s`**) |
| Caída (falta, gambeta recibida) | `pitch_caida`, `_s`, `_e`, `_w` | 4 (**nuevo**) |
| Control de pecho (balón aéreo) | `pitch_control` | N (**procesado nuevo**) |
| Volea (remate apenas la bajás) | `pitch_volea` | N |
| Chilena (8 % de los cabezazos) | `pitch_chilena` | N |
| Cuerpeo (entrada fallida) | `pitch_cuerpeo` | N |
| Saque de banda | `pitch_saque_e/_w` | E, O (**nuevo**) |
| Barrera de tiro libre | `pitch_barrera`, `_s` | N, S (**nuevo**) |
| Festejo / lamento / protesta | `celeb_*` (usuario), `pitch_festejo`, `lamento`, `pitch_protesta` | S |
| Arquero: atajada, estiradas, volada, pasos laterales | `gk_atajada*`, `gk_estirada_*`, `gk_volada*`, `gk_paso_*` | S y N |
| Arquero con la pelota / saque largo | `gk_hold`, `gk_hold_n`, `gk_saque_largo`, `_n` | S, N (**nuevo**) |
| Arquero: saque con la mano, puños, achique | `gk_lanzar`, `gk_punos`, `gk_achique` (+ `_n`) | S, N (**nuevo 17-oct**) |
| Regate de costado / cabezazo de frente | `pitch_regate_e/_w`, `pitch_cabezazo_s` | (**nuevo 17-oct**) |
| Árbitro: correr, silbato, amarilla, roja | `assets/referee/negro/*` | 4 + de frente |
| Jueces de línea: espera, banderín | `assets/referee/linesman/*` | — |

## Existen pero el prototipo no los usa todavía
`lesion`, `cambio` (sustituciones/lesiones no están en el prototipo),
`arenga`, `himno` (previa), `gk_salto`, árbitro `var`, `celeb_*` restantes.

## Faltan (candidatos a generar con PixelLab)
- Entrada / caída / control / volea en diagonales y al sur.
- Abrazo de compañeros en el festejo, saludo al público.
- Lesión en cancha y camilla (camilleros existen en el juego, falta conectarlos).
- Árbitro: ventaja (brazos adelante), señalar penal.

## Peinados (17-oct)
Los 17 peinados existen de frente (`hair/`), espaldas (`hair_n/`) y costado
(`hair_e/`, `hair_w/`), generados por `tools/hair_views.py`, que también
rastrea la cabeza en cada cuadro de cancha (`AnimHeadOffsets.VIEWS`).
**Después de agregar o regenerar animaciones de cancha, correr
`python tools/hair_views.py`.**
