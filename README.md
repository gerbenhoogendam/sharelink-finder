# Sharelink - Finder

Menubalk-app voor macOS die een link maakt naar een bestand of map in Dropbox, Google Drive, Synology Drive of een servershare. De ontvanger klikt, en het bestand opent in zijn of haar **eigen** lokale kopie, ongeacht gebruikersnaam en ongeacht of Dropbox uit de homefolder of via File Provider draait.

*A macOS menu bar app that turns a file in Dropbox, Google Drive, Synology Drive or an SMB share into a link that opens the same file in the recipient's own local copy. UI is in Dutch.*

## Hoe het werkt

1. Selecteer een bestand of map in Finder en kies in de menubalk **Link bestand**, **Link map** of **Link map & bestand**. De link staat op het klembord.
2. De link is een gewoon `https://`-adres, dus klikbaar in Mail, Outlook, Teams, WhatsApp en Slack:
   `https://gerbenhoogendam.github.io/sharelink-finder/#file/dropbox/Klanten/Offerte.pdf`
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

Standaard wijzen links naar de pagina in `docs/` van deze repo. Een eigen adres instellen, zonder opnieuw te bouwen:

```zsh
defaults write nl.itgsolutions.sharelink LinkBase 'https://open.jouwdomein.nl/#'
```

Host dan `docs/index.html` op dat adres. Voor servershares die via IP én via hostnaam gemount worden, is er `HostAliases` in hetzelfde voorkeurendomein, bijvoorbeeld `{ "192.168.1.10" = "fileserver.local"; }`.

## Beperkingen

- Windows en iPhone worden niet ondersteund; de pagina toont dan "Ongeldige link".
- Online-only bestanden worden eerst gedownload, dus een groot bestand opent met vertraging.
- Google Drive: de bovenste map ("Mijn Drive", "Gedeelde drives") wordt taalonafhankelijk gecodeerd; diepere mapnamen moeten exact overeenkomen.
- `build.sh` signeert ad hoc; `install.sh` haalt daarom de quarantaine-vlag van de app af. Voor verspreiding buiten je eigen Macs doet `release.sh` het volledige werk: Developer ID-signing met hardened runtime, notarisatie en een geniet ticket, met als resultaat `build/Sharelink - Finder.zip`.

## Licentie

MIT, zie [LICENSE](LICENSE).
