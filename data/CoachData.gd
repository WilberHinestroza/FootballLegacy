extends Resource
class_name CoachData

## Entrenador de un club. Generado DETERMINISTA por WorldFactory a partir
## de (world_seed, club_id) — igual que los propios clubes: no se persiste
## nada de esto. Lo único que persiste es la RELACIÓN con el usuario:
## PlayerData.coach_trust (ver CoachRelations.gd, que centraliza esa
## matemática).
##
## PLACEHOLDER: nombre y estilo son generados hasta el pipeline de import
## real. Sin nombres de entrenadores reales (misma disciplina que con los
## futbolistas).

const STYLES := ["Disciplinario", "Paternal", "Pragmático", "Exigente", "Cercano"]

@export var coach_id: String = ""
@export var club_id: String = ""
@export var coach_name: String = ""
@export var style: String = "Pragmático"
@export var demanding: int = 50 # 0-100: cuánto castiga un mal partido / cuánto exige para confiar

## IA propia del DT (deterministas, no se persiste — ver Formations.gd):
@export var formation: String = "4-3-3"
@export var philosophy: String = "Equilibrado"     # Ofensivo / Equilibrado / Defensivo
@export var play_style: String = "Posesión"         # Posesión / Directo / Contraataque / Presión alta
