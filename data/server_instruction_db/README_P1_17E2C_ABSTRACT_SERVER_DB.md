# P1-17E2C — abstract server instruction DB

Ces fichiers `.db` sont des JSON abstraits chargés par Godot. Ils préparent les emplacements qui recevront les mécaniques identifiées dans l’audit DOLSharp/OpenDAoC, sans appliquer de logique serveur réelle.

Règles :

- aucune coordonnée serveur n’est appliquée au runtime ;
- `coordinate_frame_confirmed=false` par défaut ;
- les vraies tables OpenDAoC/DOL devront être importées plus tard ;
- `unified_client_instruction_contracts_p1_17e2c.db` reprend les lignes de la matrice P1-17E2B.

Entrée principale : `manifest_p1_17e2c.db`.
