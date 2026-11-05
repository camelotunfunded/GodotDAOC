# P1-17E2D/E2E — OpenDAoC SQL import slots

Ce dossier contient les slots abstraits destinés à recevoir les tables SQL OpenDAoC.

Les fichiers OpenDAoC complets ne sont pas inclus dans le client Godot. L'importeur sait lire un dossier local `opendaoc-db-core` et produire un rapport de couverture, sans effet runtime.

Chemins locaux cherchés par défaut en E2E :

```text
res://data/server_dumps/opendaoc/opendaoc-db-core
res://data/server_instruction_db/opendaoc-db-core
res://opendaoc-db-core
```

Commande debug :

```text
/opendaocdb status
/opendaocdb report [path]
```

Exports :

```text
user://daoc_opendaoc_sql_realdb_report.json
user://daoc_opendaoc_sql_realdb_report.txt
```

Garde-fous :

```text
runtime_enabled=false
coordinate_frame_confirmed=false
no runtime spawn
no teleport apply
```
