# Crédits & licence

L'**architecture** de lecture NIF de ce projet (lecture in-engine → cache `PackedScene`,
aiguillage par type de bloc, conversion de coordonnées centralisée, prébake par lot)
est inspirée du projet **godotwind** de **Liho** :

> https://github.com/lihogloglo/godotwind — Licence **MIT**, Copyright (c) 2026 Liho.

Le code de ce projet est une réécriture originale adaptée au client **DAoC / Eden**
(NetImmerse **4.2.2.0** et Gamebryo **10.1.0.0**), distincte du code de godotwind
(calibré pour Morrowind). La disposition `NiTriShapeData` 4.2.2.0 provient du
reverse-engineering du projet Eden (voir `NOTE_TERRAIN §11`), pas de godotwind.

Conformément à la licence MIT de godotwind, l'attribution ci-dessus est conservée.
Si tu redistribues, garde ce fichier.
