# Tutoriel — préparer son client DAoC pour Godot

## 1. Travailler sur une copie

Ne modifiez jamais votre installation principale. Copiez tout le dossier DAoC
dans un emplacement de travail, puis pointez `DAOC_CLIENT_ROOT` vers cette copie.

Sous PowerShell, pour la session courante :

```powershell
$env:DAOC_CLIENT_ROOT = "D:/Jeux/DAoC-Godot"
```

Le chemin ne doit pas être écrit dans le dépôt ni partagé avec une archive.

## 2. Ce que signifie « patcher le client »

Le projet ne remplace pas les archives originales `.mpk` et `.npk`. Il les lit
comme sources. Les fichiers ajoutés à côté servent de surcharges : PNG, cartes
PBR, GLB ou caches Godot. Une surcharge peut donc être supprimée sans détruire
les données d'origine.

Ordre recommandé :

1. conserver les archives DAoC intactes ;
2. convertir uniquement les textures nécessaires en PNG ;
3. générer les caches dans `_godot_daoc_cache` ;
4. ajouter vos remplacements dans un dossier séparé ;
5. tester une zone avant de traiter tout le client.

## 3. Première ouverture

Ouvrez `project.godot` avec Godot 4.6.x. Au premier lancement, l'import des
ressources Godot peut être long. Lancez ensuite `ZoneViewer.tscn`.

Le client cherche sa source dans cet ordre : chemin configuré, variable
`DAOC_CLIENT_ROOT`, puis voisinage connu. Pour un paquet partagé, utilisez la
variable d'environnement : elle ne révèle aucun chemin personnel.

## 4. Cache local

Le dossier `_godot_daoc_cache` appartient à l'utilisateur et ne doit pas être
versionné. Il peut contenir les index de zones, textures converties, scènes
préparées et données de splat. S'il devient incohérent après une modification,
renommez-le et laissez les outils le reconstruire ; ne touchez pas aux archives
originales.

## 5. Ajouter un modèle personnalisé

Le format conseillé est GLB :

1. produire le modèle et son squelette dans Blender ;
2. exporter en GLB avec textures intégrées ou chemins relatifs ;
3. importer le GLB dans Godot ;
4. créer une scène `.tscn` qui instancie le modèle ;
5. raccorder cette scène par une table de correspondance plutôt que modifier le
   lecteur NIF pour un seul objet.

Pour les personnages, gardez des points d'attache stables pour les mains, le
bouclier, la ceinture et le dos. Les animations doivent rester dans un format
intermédiaire reproductible.

## 6. Ajouter une zone ou une mécanique

Le monde Godot possède réellement un relief, des collisions et une altitude.
Une zone volante, le vol, des passerelles ou un combat aérien doivent donc être
implantés comme des systèmes Godot normaux. Évitez les contournements hérités du
client 2001 quand le moteur moderne fournit déjà la primitive adaptée.

## 7. Raccorder un serveur DOL

La base contient le protocole et une simulation locale. Aucun identifiant ni
serveur privé n'est fourni. Configurez votre propre profil local hors du dépôt.
Si vous voulez lancer un serveur depuis l'écran de connexion, définissez
`DOL_SERVER_DLL` vers votre propre `DOLServer.dll`.

## 8. Partager un patch propre

Distribuez seulement :

- votre code et vos tables ;
- les assets dont vous possédez les droits ;
- un manifeste de fichiers et de licences ;
- les scripts de génération ;
- les sommes SHA-256 des résultats attendus.

Ne distribuez pas les archives, textures, NIF, DLL, captures réseau, identifiants
ou caches provenant de votre client. Un bon patch est reproductible sur une
copie propre du client du destinataire.

