## NifCoordinateSystem — conversion NIF -> Godot, CENTRALISEE ICI ET NULLE PART AILLEURS.
##
## Lecon heritee de godotwind (et de notre propre experience terrain) : si la
## conversion d'axes est eparpillee dans le code, on melange "accumuler puis
## convertir" et "convertir puis accumuler", et on obtient des modeles tournes
## ou en miroir, impossibles a deboguer. => UN seul fichier. Si un modele sort
## en miroir, on corrige UNE constante ici.
##
## Statut : HYPOTHESE a valider sur tes vrais NIF DAoC.
## NIF (NetImmerse/Gamebryo) est Z-up ; Godot est Y-up, -Z vers l'avant.
## Convention de depart (identique a godotwind, meme lignee NetImmerse) :
##     Godot.x =  NIF.x
##     Godot.y =  NIF.z
##     Godot.z = -NIF.y
class_name NifCoordinateSystem
extends RefCounted

## Echelle unite-jeu -> metre. DAoC : NON nail (NOTE_TERRAIN §8 : ~50-90 u/m).
## On reste en unites de jeu (1.0) pour ne PAS deformer la geometrie ; la mise a
## l'echelle monde est un probleme separe, deja gere cote terrain (world_scale).
const UNIT_SCALE: float = 1.0

## Matrice de changement de base S : g = S * n  (NIF -> Godot).
## Colonnes de S = images des axes NIF dans Godot.
##   S * (1,0,0) = (1,0,0)   ; S * (0,1,0) = (0,0,-1) ; S * (0,0,1) = (0,1,0)
const S := Basis(
	Vector3(1, 0, 0),
	Vector3(0, 0, -1),
	Vector3(0, 1, 0)
)


## Convertit une position NIF en position Godot.
static func position(p: Vector3) -> Vector3:
	return (S * p) * UNIT_SCALE


## Convertit une rotation NIF (Basis) en rotation Godot : R' = S * R * S^-1.
static func rotation(r: Basis) -> Basis:
	return S * r * S.inverse()


## Convertit un triplet (translation, rotation, echelle) NIF en Transform3D Godot.
## C'est CE point d'entree que doit appeler le convertisseur, jamais les formules brutes.
static func transform(translation: Vector3, rot: Basis, scale: float) -> Transform3D:
	var b: Basis = rotation(rot).scaled(Vector3(scale, scale, scale))
	return Transform3D(b, position(translation))


## Convertit une normale (direction, pas de translation ni d'echelle).
static func normal(n: Vector3) -> Vector3:
	return (S * n).normalized()
