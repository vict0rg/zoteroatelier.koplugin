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

**Additional user confirmation (2026-10-11):** downloaded attachments were present in the Kindle's local `koreader/zotero/storage/<ATTACHMENT_KEY>/` directory and opened normally with Wi-Fi disabled. The EPUB itself is stored there. KOReader also created an independent derived `.cr3` reading/rendering cache under `koreader/cache/cr3cache/`; that cache is **not** the original EPUB and is not the authoritative attachment store. This confirms offline reading of locally stored Zotero attachments.

This is a significant *manual* Kindle compatibility result, not evidence of universal compatibility or a production release. The tester did not separately confirm the article's precise file format, whether the specific Kindle documents were initially absent from local storage, or the network source of each individual file download.

## New Kindle documents cover-gallery layout — awaiting device validation (2026-10-11)

The Kindle owner uses `/mnt/us/documents` as the KOReader home folder with recursive subfolder display and a cover mosaic. After a reported file-browser freeze while browsing an internal `/mnt/.../storage` directory and a forced Kindle restart, the experimental fork was modified so its **Kindle-specific** download destination is `/mnt/us/documents/Zotero/storage/<attachment-key>/<filename>`. The regular KOReader `zotero.db`, OAuth settings and logs remain in `/mnt/us/koreader/zotero`; Flatpak keeps its old destination.

A backup-enabled, no-overwrite USB migration script was added to relocate the entire old `storage` tree, including sidecar metadata, within the Kindle volume. The script refuses to merge if both old and new storage trees exist. **This change is implemented and published but has NOT yet been installed or validated on the user's Kindle.** The navigation freeze's root cause remains unknown; this is a requested organization change, not a demonstrated fix for that crash.

## Not yet established

- Broader Kindle compatibility, performance, large-library behavior, and repeatability beyond the successful Oasis smoke test
- Android compatibility
- Behavior with missing files, special characters, network interruptions, and revoked OAuth tokens
- Annotation behavior and long-term synchronization integrity
- Automated functional tests and broader compatibility

**Do not present this as a production release yet.** These are successful manual smoke tests, not comprehensive QA.

The original [Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) and [KOReader](https://github.com/koreader/koreader) authors remain credited. Feature requirements and manual validation: [@vict0rg](https://github.com/vict0rg); implementation assistance: OpenAI ChatGPT (GPT-6).
