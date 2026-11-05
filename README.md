# DAoC Godot Community Base

Ce dépôt n'est pas un remaster figé ni un jeu fini. C'est un **client DAoC
reconstruit sous Godot 4**, destiné à servir de base de développement.

Le gameplay, les zones, les modèles et les animations restent ceux du client
que possède l'utilisateur. Le dépôt ne fournit aucun fichier propriétaire de
DAoC et ne contient aucun élément du projet personnel de l'auteur.

## Ce que permet la base

- conserver le rendu d'origine ou le faire évoluer ;
- lire les zones, tables, modèles NIF et animations du client installé ;
- utiliser un vrai terrain, des collisions, l'altitude et la physique Godot ;
- ajouter des scènes GLB produites dans Blender sans repasser par NIF ;
- activer ou générer des matériaux PBR ;
- développer des zones, objets, quêtes, systèmes et effets modernes ;
- continuer le client hors ligne ou le raccorder à un serveur compatible DOL.

## Démarrage rapide

1. Installer Godot 4.6.x.
2. Faire une copie de son client DAoC légalement obtenu.
3. Définir la variable `DAOC_CLIENT_ROOT` vers cette copie.
4. Ouvrir `project.godot` dans Godot.
5. Lancer `ZoneViewer.tscn` pour explorer ou `DaocGame.tscn` pour la boucle de jeu.

Lire ensuite [TUTORIEL_PATCH_CLIENT.md](TUTORIEL_PATCH_CLIENT.md) et
[GUIDE_PBR.md](GUIDE_PBR.md).

## Ce qui a volontairement été retiré

- comptes, identifiants, configurations locales et chemins de machines ;
- captures réseau et personnages de test personnels ;
- journaux, relais d'agents, hypothèses et rapports de recherche ;
- graphismes HD et assets du projet personnel NAMED ;
- caches, exports, captures d'écran et binaires générés ;
- ressources dont la redistribution n'est pas clairement autorisée.

Les textures, modèles et caches nécessaires sont reconstruits localement depuis
le client de chaque utilisateur. Cette règle garde le dépôt léger et évite de
redistribuer les données du jeu.

## Structure utile

- `src/` : client, lecteur NIF, monde, gameplay, réseau et interface ;
- `data/` : petites tables dérivées nécessaires au fonctionnement ;
- `addons/` : dépendances Godot redistribuables ;
- `scenes/` : scènes d'entrée légères ;
- `tools/` : outils de conversion et de maintenance conservés ;
- `docs/` : reprise, audit et points à poursuivre.

## État

Le projet est une base de travail. Plusieurs systèmes sont avancés, mais toute
publication doit encore vérifier les licences des données dérivées et tester la
construction sur un client DAoC propre. Voir [docs/REPRISE.md](docs/REPRISE.md).

