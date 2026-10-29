# Sharelink - Finder

Menubalk-app voor macOS die een link maakt naar een bestand of map in Dropbox, Google Drive, Synology Drive of een servershare. De ontvanger klikt, en het bestand opent in zijn of haar **eigen** lokale kopie, ongeacht gebruikersnaam en ongeacht of Dropbox uit de homefolder of via File Provider draait.

*A macOS menu bar app that turns a file in Dropbox, Google Drive, Synology Drive or an SMB share into a link that opens the same file in the recipient's own local copy. UI is in Dutch.*

**Download:** de nieuwste gesigneerde en genotariseerde versie staat bij [Releases](https://github.com/gerbenhoogendam/sharelink-finder/releases). Uitpakken, naar Programma's slepen, één keer starten.

## Hoe het werkt

1. Selecteer een bestand of map in Finder en kies in de menubalk **Link bestand**, **Link map** of **Link map & bestand**. De link staat op het klembord.
2. De link is een gewoon `https://`-adres, dus klikbaar in Mail, Outlook, Teams, WhatsApp en Slack:
   `https://share-link.nl/#file/dropbox/Klanten/Offerte.pdf`
3. De pagina op dat adres stuurt de browser door naar `sharelink://file/dropbox/Klanten/Offerte.pdf`. Het pad staat achter `#` en wordt nooit naar de server gestuurd.
4. Sharelink - Finder op de Mac van de ontvanger zoekt de eigen Dropbox-, Google Drive- of Synology-map, of mount de servershare, en opent het bestand of toont het in Finder.

Voorwaarde: verzender en ontvanger hebben dezelfde mappenstructuur, bijvoorbeeld dezelfde teammappen in Dropbox.

## Installatie

Nodig: macOS 13 of nieuwer, en om te bouwen de Xcode Command Line Tools (`xcode-select --install`).

```zsh
./build.sh      # bouwt build/Sharelink - Finder.app en draait een zelftest
./install.sh    # kopieert naar /Applications, registreert sharelink:// en start de app
```

Bij de eerste klik vraagt macOS of de app Finder mag lezen. De app start voortaan bij het inloggen; dat zet je uit onder Systeeminstellingen, Algemeen, Inloggen en extensies.

Ook de Macs die alleen links **ontvangen** hebben de app nodig, want die opent de `sharelink://`-link.

## Gebruik

- **Menubalk:** icoon van de provider plus Link bestand, Link map, Link map & bestand. Meerdere geselecteerde bestanden geven meerdere links.
- **Rechtsklik:** dezelfde drie opties staan onder Services.
- **Ondersteund:** Dropbox (homefolder en File Provider), Google Drive, Synology Drive, SMB-servershares. OneDrive en lokale schijven geven geen link.

## Eigen domein of hostnamen

Standaard wijzen links naar `share-link.nl`, de pagina in `docs/` van deze repo. Een eigen adres instellen, zonder opnieuw te bouwen:

```zsh
defaults write nl.itgsolutions.sharelink LinkBase 'https://open.jouwdomein.nl/#'
```

Host dan `docs/index.html` op dat adres. Voor servershares die via IP én via hostnaam gemount worden, is er `HostAliases` in hetzelfde voorkeurendomein, bijvoorbeeld `{ "192.168.1.10" = "fileserver.local"; }`.

## Beperkingen

- Windows en iPhone worden niet ondersteund; de pagina toont dan "Ongeldige link".
- Online-only bestanden worden eerst gedownload, dus een groot bestand opent met vertraging.
- Google Drive: de bovenste map ("Mijn Drive", "Gedeelde drives") wordt taalonafhankelijk gecodeerd; diepere mapnamen moeten exact overeenkomen.
- `build.sh` signeert ad hoc; `install.sh` haalt daarom de quarantaine-vlag van de app af. Voor verspreiding buiten je eigen Macs doet `release.sh` het volledige werk: Developer ID-signing met hardened runtime, notarisatie en een geniet ticket, met als resultaat `build/Sharelink - Finder.zip`.

## Laat een AI het zelf nakijken

Geloof ons niet op ons woord. Plak deze opdracht in ChatGPT, Claude, Gemini of een andere AI; de code is openbaar, dus die kan hem regel voor regel lezen.

```
Ik overweeg een macOS-app in te zetten binnen onze organisatie: Sharelink - Finder.
Website: https://share-link.nl
Broncode: https://github.com/gerbenhoogendam/sharelink-finder

Wat de app belooft: je selecteert een bestand in Dropbox, Google Drive, Synology Drive of op een servershare en maakt er een link van die bij een collega precies dat bestand opent, in diens eigen lokale kopie. De makers stellen dat er niets wordt geüpload, niets wordt gelogd en dat er geen gegevens over onze organisatie, onze bestanden of onze medewerkers naar buiten gaan.

Onderzoek dat grondig en onafhankelijk, alsof je onze security officer bent. Lees de volledige broncode in de repository (CloudLinks.swift, App.swift, docs/index.html, build.sh, install.sh, release.sh, Info.plist en Sharelink.entitlements) en beantwoord:

1. Netwerkverkeer. Maakt de app zelf ooit een netwerkverbinding, en zo ja naar welke adressen? Wat staat er precies in een link, en wat bereikt de server op share-link.nl wel en niet? Leg uit wat het hekje (#) in de link doet.
2. Gegevens. Welke informatie over bestanden, mappen, gebruikersnamen of de computer komt in een link terecht, en bij wie kan die terechtkomen?
3. Rechten. Welke macOS-permissies en entitlements vraagt de app (Finder-automatisering, hardened runtime, sandbox) en waarvoor worden ze gebruikt? Vraagt de app iets dat meer is dan nodig?
4. Lokaal gedrag. Wat doet de app met het bestandssysteem? Kan een link iets openen buiten onze gedeelde mappen, bijvoorbeeld via ../ of een absoluut pad? Welke bestandstypen opent de app wel en niet automatisch?
5. Verspreiding. Is de app gesigneerd en genotariseerd, en klopt wat de releasenotes daarover zeggen met de scripts in de repository?
6. Afhankelijkheden. Gebruikt de app externe bibliotheken, analytics, crashrapportage of een updatemechanisme dat naar buiten belt?
7. Misbruik. Welk risico loopt een medewerker die op een kwaadaardig gemaakte sharelink-link klikt? Wat is het slechtst denkbare scenario?

Geef daarna een duidelijk oordeel: kunnen wij deze app met een gerust hart op de Macs van onze medewerkers installeren? Onderbouw elk punt met het bestand en de regel waar je het in de code hebt gezien, zeg expliciet wat je niet hebt kunnen controleren, en noem de voorwaarden of aanpassingen die je zou aanraden voordat we uitrollen.
```

## Licentie

MIT, zie [LICENSE](LICENSE).
