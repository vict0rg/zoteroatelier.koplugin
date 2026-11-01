# Proposition au mainteneur de Zotero Atelier

**Titre suggéré :** Proposition : accès aux pièces jointes Zotero stockées sur Dropbox depuis KOReader

Bonjour,

Merci pour votre travail sur **Zotero Atelier** ! J'utilise KOReader sous Linux et je souhaite également utiliser le plugin sur un **Kindle Oasis avec jailbreak**.

Dans ma bibliothèque personnelle Zotero, les références et les collections sont synchronisées normalement, mais **les pièces jointes PDF/EPUB sont conservées dans Dropbox**, dans l'arborescence Zotero `storage/<clé_de_la_pièce_jointe>/<nom_du_fichier>`. Cela permet de ne pas dupliquer toute la bibliothèque sur la liseuse ni de dépendre du stockage payant de Zotero.

J'ai donc créé un [fork expérimental de Zotero Atelier](https://github.com/vict0rg/zoteroatelier.koplugin/tree/feature/dropbox-on-demand) pour proposer une intégration directe de Dropbox **au sein du même plugin** :

- navigation habituelle dans les collections et références Zotero ;
- recherche de la pièce jointe locale en priorité ;
- en son absence, récupération **à la demande** depuis Dropbox, grâce à la clé de la pièce jointe Zotero ;
- mise en cache locale et ouverture dans KOReader ;
- configuration Dropbox dans le menu de Zotero Atelier, avec autorisation **OAuth 2 / PKCE par QR code** et permission de lecture (`files.content.read`) ;
- maintien du mécanisme Zotero/WebDAV existant comme solution de repli.

**Premiers résultats :** sur **Linux Mint / KOReader Flatpak**, l'authentification Dropbox fonctionne et j'ai pu **ouvrir un PDF puis un EPUB** de ma bibliothèque personnelle en passant par Zotero Atelier. Ces essais sont [documentés ici](https://github.com/vict0rg/zoteroatelier.koplugin/blob/feature/dropbox-on-demand/doc/manual-test-results.md).

**Limites actuelles :** il s'agit encore d'un prototype. Les tests sur **Kindle Oasis** restent à effectuer, de même que des vérifications plus complètes (lecture hors ligne, erreurs réseau, annotations et robustesse). Je ne le présente donc pas comme une version prête pour une publication officielle.

Le fork conserve la **licence GPLv3 et les crédits du projet d'origine**. L'implémentation Dropbox de KOReader a servi de référence technique, sans reprise de son code AGPLv3. J'ai défini les besoins et réalisé les premiers tests, avec une assistance à la programmation de **ChatGPT (GPT-6)**.

**Cette fonctionnalité pourrait-elle vous intéresser pour Zotero Atelier ?** Si oui, je serais heureux de tenir compte de vos recommandations, d'améliorer les points nécessaires et de proposer ensuite une *pull request* pour examen. Il n'y a évidemment aucune obligation de l'intégrer.

Merci encore pour votre travail et pour votre avis !

— @vict0rg
