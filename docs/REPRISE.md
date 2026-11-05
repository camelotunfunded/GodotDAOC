# Reprendre le développement

## Base de travail

Le paquet contient uniquement le code nécessaire à la continuité. Les preuves,
captures et recherches internes ont été retirées. Les noms historiques encore
présents dans certains symboles sont des fixtures techniques anciennes ; ils ne
contiennent ni mot de passe ni configuration locale et pourront être
généralisés progressivement.

## Ordre conseillé

1. Construire un client de test propre selon le tutoriel.
2. Vérifier l'ouverture de `ZoneViewer.tscn` sans asset HD.
3. Rendre le générateur de cache entièrement guidé depuis Godot.
4. Ajouter une scène de diagnostic publique sans personnage personnel.
5. Porter les correctifs génériques listés dans `AUDIT_NAMED.md`, un par un.
6. Ajouter pour chaque port un test hors ligne déterministe.
7. Créer un manifeste automatique des fichiers générés et de leurs licences.

## Règles de contribution

- aucun chemin absolu dans le code ;
- aucun secret, compte, IP privée ou personnage personnel dans les fixtures ;
- aucun fichier du client DAoC dans Git ;
- toute donnée générée doit décrire sa source et sa méthode ;
- toute ressource tierce doit avoir une licence compatible ;
- les options HD restent facultatives ; le mode vanilla doit continuer à
  fonctionner ;
- préférer GLB pour les nouveaux modèles et des tables de correspondance pour
  les raccorder ;
- tester hors ligne avant tout test réseau.

## Limites connues

- le paquet n'embarque pas les scènes de personnages et de PNJ préconverties ;
- certains anciens noms de fixtures subsistent dans le code ;
- la préparation complète du cache doit encore être simplifiée pour un public
  non technique ;
- les ports depuis NAMED ne sont pas intégrés automatiquement ;
- la compatibilité doit être vérifiée sur plusieurs versions de clients DAoC.

