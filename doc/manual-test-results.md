# Manual test status — Dropbox on-demand integration

Date: 2026-10-11

## Confirmed by the project tester

Environment: Linux Mint desktop (`pesquisa03`), KOReader installed as Flatpak (`rocks.koreader.KOReader`).

| Test | Result |
| --- | --- |
| Load the experimental Zotero Atelier plugin | **PASS** |
| Browse personal Zotero library metadata and collections | **PASS** |
| Authorize Dropbox via in-plugin QR code / OAuth PKCE | **PASS** |
| Save authorization and enable on-demand downloads | **PASS** |
| Open a personal-library PDF attachment from Dropbox | **PASS — user confirmed** |
| Open a personal-library EPUB attachment from Dropbox | **PASS — user confirmed** |

The user's Dropbox setup has a remote `storage/ATTACHMENT_KEY/filename` structure. The test confirms that at least one PDF and one EPUB can be accessed through the Zotero Atelier browsing workflow.

## Kindle Oasis — first successful end-to-end reading test (2026-10-11)

Environment: Kindle Oasis with KOReader and the experimental Zotero Atelier + Dropbox branch. After an initial failure, the tester supplied read-only SQLite diagnostics: local Kindle database had schema version `0`, library cursor `38750`, **0 collections**, **0 items**, and **no root collection**. The Linux Mint Flatpak database contained **85 collections, 602 items and 260 attachments**. The branch was repaired to address SQLite initialization (SQL string quoting, creation of item types/root collection, and recovery of an incorrectly advanced empty-library cursor).

After applying the repair and retrying **Synchronize**, the tester reported that Zotero requests were occurring and successfully opened both **an article** and **an EPUB book** via Zotero Atelier on the **Kindle Oasis**.

| Test | Result |
| --- | --- |
| Load experimental plugin and configuration on Kindle Oasis | **PASS — user confirmed** |
| Recover initial synchronization after SQLite initialization failure | **PASS — user confirmed that browsing and reading now work** |
| Browse and open an article via Zotero Atelier on Kindle | **PASS — user confirmed** |
| Open an EPUB book via Zotero Atelier on Kindle | **PASS — user confirmed** |
| Independently verify Dropbox download source for each Kindle attachment | **NOT YET INDEPENDENTLY VERIFIED** |
| Reopen already downloaded files with Kindle Wi-Fi disabled | **PASS — user confirmed local `storage` cache and offline opening** |

**Additional user confirmation (2026-10-11):** files were present in the Kindle's local `storage` directory and opened normally with Wi-Fi disabled. This confirms offline reading of the locally cached attachments. 

This is a significant *manual* Kindle compatibility result, not evidence of universal compatibility or a production release. The tester did not separately confirm the article's precise file format, whether these specific Kindle documents were initially absent from local storage, whether these specific Kindle documents were initially absent from local storage; **offline reopening is now confirmed**.

## Not yet established

- Broader Kindle compatibility, performance, large-library behavior, and repeatability beyond the successful Oasis smoke test
- Android compatibility
- Behavior with missing files, special characters, network interruptions, and revoked OAuth tokens
- Annotation behavior and long-term synchronization integrity
- Automated functional tests and broader compatibility

**Do not present this as a production release yet.** These are successful manual smoke tests, not comprehensive QA.

The original [Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) and [KOReader](https://github.com/koreader/koreader) authors remain credited. Feature requirements and manual validation: [@vict0rg](https://github.com/vict0rg); implementation assistance: OpenAI ChatGPT (GPT-6).
