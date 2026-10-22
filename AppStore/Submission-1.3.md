# AtlasView 1.3 – App Store Connect

Stand: 22. Oktober 2026. Version 1.3, Build 1. Ein gemeinsames iOS-Archiv für iPhone, iPhone Duo und iPad; kein separater Build für normale iPhones.

## Vorbereitete Texte

Die englischen Connect-Texte stehen in `ReleaseNotes.md`, `PromotionalText.md`, `Description.md` und `ReviewNotes.md`. Der Duo-Support ist jeweils berücksichtigt. Bestehende deutsche UI-Texte sind unverändert.

Deutscher Vorschlag für „Neu in dieser Version“:

> AtlasView ist bereit für iPhone Duo. Entdecke die Weltkarte auf dem äußeren und dem aufgeklappten inneren Display. In breiten Fenstern startet die Uhrkarte seitlich und hält die Kartenmitte frei. Ihre verschiebbare Position passt sich an den verfügbaren Platz an.
>
> Die Ansicht für Tag, Dämmerung und Nacht steht weiterhin auf allen unterstützten Geräten zur Verfügung.

## Duo-Screenshots

Upload-Auswahl in `Screenshots/iphone-duo/`, in dieser Reihenfolge:

| Datei | Display | Pixel | Original vom Desktop |
| --- | --- | --- | --- |
| `01-inner-europe.jpg` | innen, Querformat | 2853 × 2007 | 08.13.49 |
| `02-inner-yukon.jpg` | innen, Uhrkarte rechts | 2853 × 2007 | 08.14.18 |
| `03-outer-yukon.jpg` | außen, Hochformat | 1398 × 2034 | 08.14.57 |
| `04-outer-welcome.jpg` | außen, Willkommen | 1398 × 2034 | 08.11.58 |

Alle vier Dateien sind JPEGs ohne Alpha-Kanal in Originalauflösung. Der Bildinhalt wurde nicht bearbeitet; die Original-PNGs auf dem Desktop bleiben erhalten. Die Auswahl zeigt die aufgeklappte Karte zuerst, danach die verschobene Uhrkarte und das äußere Display.

Laut Apple erscheint nach Einreichung von Duo-Screenshots ein Badge zur Duo-Optimierung auf der App-Store-Produktseite. Dafür wird kein Badge in die Screenshots eingebrannt und kein App-Code-Schalter gesetzt. Die Anzeige in Connect wurde hier nicht geprüft.

## Archiv und Prüfung

Das signierte Release-Archiv wurde erfolgreich erstellt: `/private/tmp/AtlasView-1.3.xcarchive`. Achtung: Dies ist ein temporärer Speicherort; das Archiv vor längerfristiger Aufbewahrung in einen dauerhaften Ordner kopieren.

Build-Ergebnis: `ARCHIVE SUCCEEDED`. Version, Buildnummer und iOS-Geräteplattform wurden im erzeugten Archiv geprüft. `git diff --check` ist erfolgreich. App-Store-Validierung, Upload und die verbleibenden Gerätetests stehen noch aus.

## Noch vor der Einreichung

1. Auf dem normalen physischen iPhone mit dem aktuellen Stand kurz testen: Start, Willkommen/Hilfe, Karte bewegen, Stadt wählen, Uhrkarte verschieben und Hoch-/Querformat. Die Duo-Screenshots ersetzen diesen Test nicht.
2. Auf dem Duo noch Hilfe und größere Schrift prüfen, soweit noch nicht getestet. Die gelieferten Bilder belegen die sichtbaren Layouts; sie sind kein automatischer Test von Zustandswechseln.
3. Release-Archiv in Xcode Organizer öffnen, „Validate App“ ausführen und über „Distribute App“ → „App Store Connect“ hochladen. Kein Simulator-Build kann hochgeladen werden. Das Archiv wurde nicht automatisch validiert oder hochgeladen.
4. Nach Verarbeitung in Connect Version 1.3 anlegen bzw. öffnen und Build 1 auswählen. Falls dort bereits 1.3 (1) existiert, ist vor einem weiteren Upload eine höhere Buildnummer nötig.
5. Vorbereitete Texte in die passenden Sprachfelder übernehmen. Im Bereich „App Previews and Screenshots“ bzw. im Media Manager die Auswahl unter iPhone Duo hochladen. Bestehende normale iPhone- und iPad-Screenshots kontrollieren und beibehalten, sofern sie den aktuellen Stand korrekt zeigen. Duo-Screenshots kommen zusätzlich hinzu.
6. In der Produktseiten-Vorschau Reihenfolge und Zuschnitt prüfen, anschließend die Version zur Prüfung einreichen.

Die Versionsnummer wurde auf Wunsch auf 1.3 gesetzt. Buildnummer 1, Signierung, Bundle-ID, Deployment Target und Gerätefamilien bleiben unverändert.

## Apple-Quellen

- [Screenshot-Spezifikationen und Duo-Badge](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apps für Duo vorbereiten, SDK-Anforderungen](https://developer.apple.com/iphone-duo/prepare/)
- [Screenshots in Connect hochladen](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
