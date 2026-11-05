# Audit en lecture de NAMED

Audit effectué avant la création de ce paquet. Aucun fichier de NAMED n'a été
copié dans la livraison.

## Apports génériques repérés mais absents du client DAoC principal

- inventaire local : déplacement et échange atomiques, restauration de
  sauvegarde, logement mythique ;
- arbitre local : fenêtre de combat magique empêchant la régénération pendant
  les projectiles et dégâts périodiques ;
- mort PvE DOL plus complète, tombe, libération, maladie et constitution ;
- archerie classique DAoC, préparation et tir critique ;
- prise en charge locale plus complète des familiers du Theurgist ;
- ROG : générateur d'objets et application des bonus de statistiques,
  résistances, puissance, compétences et focus ;
- paquet DOL local réutilisable pour décrire populations et butins ;
- tables et bancs de contrôle pour les classes des trois royaumes ;
- zones Frontiers : royaume correct des zones 167 à 178, textures spécifiques
  et surcouche de masques/heightmaps ;
- rayon et hauteur de collision joueur configurables ;
- caméra : retour derrière le joueur configurable au virage ;
- outils d'atlas VFX et fiches fonctionnelles des sorts ;
- système VFX moderne : aiguillage par ligne/type de sort, flipbooks, impacts et
  traînée d'arme ;
- outillage de reciblage d'animations et gestes de bâton inspirés des KFA ;
- interface moderne déplaçable et sauvegarde de disposition.

## Éléments propres à NAMED, volontairement exclus

- scénario, dialogues, quêtes et lieux ;
- Terrain3D des Prés, des Saules et de Concorde ;
- UI artistique NAMED 2026 ;
- drones steampunk du Theurgist et leur direction artistique ;
- MetaHuman, X Bot, Mixamo et garde-robe ;
- assets, textures, bâtiments, faune et armures ;
- outils de production distante, Trellis, Stable Diffusion et comptes externes ;
- chemins du miroir `NAMED_CLIENT` et règles de remplacement propres à NAMED.

## Décision pour cette livraison

Ne pas fusionner aveuglément les fichiers de NAMED. Plusieurs correctifs
génériques sont entremêlés à des dépendances `NamedPaths`, `src/named`, aux
scènes Terrain3D et à des données privées. La livraison conserve donc le client
DAoC principal stable et documente les ports à faire séparément, avec tests.

Priorité de port recommandée : inventaire atomique, correctif de régénération
magique, zones Frontiers, puis ROG/arc/mort locale. Le VFX NAMED doit rester une
implémentation de référence, pas un asset livré.

