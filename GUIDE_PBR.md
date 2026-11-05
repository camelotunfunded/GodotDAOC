# Guide PBR

Godot sait exploiter des matériaux PBR même si DAoC ne fournissait à l'origine
qu'une texture couleur. Le client contient trois chemins distincts : joueur,
terrain et objets du monde.

## Cartes usuelles

- `albedo` ou `basecolor` : couleur, espace sRGB ;
- `normal` : relief fin, convention OpenGL ;
- `roughness` : rugosité, blanc = mat ;
- `metallic` : métal, généralement noir ou blanc ;
- `ao` : occlusion ambiante ;
- `ORM` : occlusion, rugosité et métal regroupés dans R, G et B.

## Génération automatique

Le runtime peut dériver une normale, une rugosité et une AO depuis l'albédo.
C'est utile pour démarrer et pour conserver un paquet léger. Ce résultat est une
estimation : une couleur sombre n'est pas automatiquement un creux et une zone
claire n'est pas automatiquement lisse.

Dans `DaocGameWorld`, les réglages `player_pbr_*`, `terrain_pbr_*` et
`world_pbr_*` permettent d'activer les trois familles et d'ajuster leur force.
Commencez en 256 px pour les cartes générées, puis augmentez seulement après
mesure de la mémoire vidéo.

## Cartes réalisées à la main

Pour un asset important, préférez des cartes d'auteur ou issues d'une source
libre clairement licenciée. N'écrasez jamais ces cartes par le générateur. Une
recette de patch doit donc traiter les remplacements manuels avant la génération
automatique et ignorer les fichiers déjà présents.

## Convention de fichiers

Placez les cartes à côté de l'albédo avec un suffixe explicite :

```text
pierre.png
pierre_normal.png
pierre_roughness.png
pierre_ao.png
pierre_metallic.png
```

Le code de `DaocWorldPbrUpgrade`, `DaocTerrainPbrUpgrade` et
`DaocPlayerPbrUpgrade` constitue la référence pour la détection et les valeurs
par défaut.

## Contrôle visuel

Vérifiez toujours en jeu :

- lumière rasante pour la normale ;
- ciel clair et intérieur sombre pour l'AO ;
- reflets mobiles pour la rugosité ;
- raccords et répétitions sur les textures tuilées ;
- consommation mémoire et temps de génération.

Le PBR est une possibilité du bac à sable, pas une obligation. Désactivé, le
client peut conserver le rendu et les performances proches du DAoC d'origine.

