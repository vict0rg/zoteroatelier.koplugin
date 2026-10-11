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

## Storage manager feature — code published, Kindle test pending

Added `zotero_storage_manager.lua` and a **Maintenance → Zotero storage and cleanup** menu entry. Its view uses KOReader's disk-space helper, scans current/legacy plugin attachment directories for PDFs/EPUBs matching exact Zotero metadata keys/filenames, and provides initially unchecked category selectors plus a two-stage confirmation before removing the selected original files. No database, credentials, .sdr sidecars or shared CR3 processing cache are deleted. The optional Kindle installer is `tools/instalar_gerenciador_espaco_kindle.sh`.

**Not yet executed or tested on the user's Kindle.** The user subsequently reported the KOReader file browser still showing `/mnt/us/koreader/zotero/storage/<KEY>` after invoking the earlier migration. This may be a remembered browser directory, an incomplete migration, or a code-path issue. Until the actual directory contents and installed plugin are checked, **do not remove the legacy storage tree** and do not infer that the move succeeded from the screenshot alone. The new Kindle device detection uses KOReader's `Device:isKindle()`, rather than a hard-coded data-dir equality; this additional change also awaits physical validation.

## Kindle PDF file containing 9 bytes instead of a PDF — confirmed diagnosis (2026-10-11)

A specific Zotero attachment (Carrey et al., 2026, key `86T2GIJT`) opened incorrectly on the Kindle, yielding KOReader's "no reader engine for this file". A user-executed byte-for-byte comparison established:

- Dropbox-synced Linux original: 5,052,243 bytes, PDF 1.7, 16 pages, SHA-256 `3b90ff38a2b00f95f84f0ded1ae8ed30c5ee6cad85d27fd403b85ab25d330c3b`
- Kindle cached .pdf: **9 bytes of ASCII text**, SHA-256 `e3ebaa16dd9d9b9fc107c42183fb6cf9d22927e1af03dbbdfa0ccc38e4e4ac31`

The original Zotero Storage fallback performed `https.request(... sink=ltn12.sink.file(io.open(targetPath, "wb")))`: an error response body could therefore be saved directly to the final PDF path and then mistakenly treated as a usable cached file. The exact HTTP status/content that produced these nine bytes has not yet been observed in the KOReader log. Dropbox on-demand previously accepted any nonzero file with HTTP 200 and also trusted nonempty old files without signature validation.

New branch code now:
- uses a small PDF/EPUB file-header validator for existing attachment resolution and freshly downloaded content;
- writes Zotero Storage fallback responses to a temporary `.zotero-part` instead of the original filename, and promotes them only after successful HTTP response and file-header verification;
- checks Dropbox downloads before rename and preserves any earlier invalid file as `.invalid-backup` if a replacement succeeds;
- preserves the Zotero SQLite database, OAuth credentials, original reading .sdr files and KOReader shared cache.

**Implementation only: not yet installed or validated on the physical Kindle.** A separate backup-enabled hotfix installer `tools/corrigir_download_pdf_kindle.sh` updates `zoteroapi.lua`, `zotero_dropbox.lua` and the new `zotero_file_validation.lua` without touching any downloaded documents. The nine-byte corrupt copy must be recovered separately, preferably from the known-good local Dropbox sync, and the PDF reopened on Kindle.

## Kindle recovered PDF after defensive-download hotfix (2026-10-11)

The user executed the safe local recovery procedure for Carrey et al. (attachment key `86T2GIJT`), preserving the previous nine-byte false PDF and copying the valid Dropbox-synced original onto the Kindle. The Kindle copy was reported by `file` as **PDF 1.7, 16 pages**, with the **same SHA-256** as the original: `3b90ff38a2b00f95f84f0ded1ae8ed30c5ee6cad85d27fd403b85ab25d330c3b`.

The user then ran `tools/corrigir_download_pdf_kindle.sh`: it successfully copied and verified `zotero_file_validation.lua`, `zotero_dropbox.lua`, and `zoteroapi.lua`, backing up prior versions. **The user confirmed Carrey's PDF now opens on Kindle Oasis.** A Lua compiler was not available for local static syntax checking at installation time. Successful opening is a smoke test of loading and locally opening the existing correct document, **not** yet a test that a new network download rejects a malformed response.

**Open questions:** cover-mosaic thumbnail missing after replacing the earlier bogus PDF (KOReader maintains its own cached book info/cover, separate from Zotero Atelier's metadata rescans); the function and provenance of an unexpected `documents/KOReader.sh` have not yet been verified on that device. The user's Zotero Atelier `Re-scan storage for local items` reported 12 attachments; this is an application catalog count and is not a measured count of only recently downloaded PDFs/EPUBs.

## Proven contents of bogus PDF; Kindle launcher identification (2026-10-11)

Follow-up USB diagnostics inspected a preserved backup of the nine-byte file previously named `Carrey et al. ...pdf`. Its **exact ASCII content was `Not found`** (nine bytes), which confirms that a textual not-found response had been persisted with a `.pdf` extension. It does not by itself prove which HTTP endpoint, which service, or the exact HTTP status produced that text. The defensive PDF/EPUB header validation and temporary-file download safeguards were published and copied to the user's Kindle. The good original PDF was restored, SHA-256 matched, and the user reported successful opening.

A newly noticed `/mnt/us/documents/KOReader.sh` was inspected without executing it. The file is a 120,147-byte POSIX shell script with the header `# Name: KOReader`, `# Author: KOReader team`, an embedded Base64 PNG icon, `# DontUseFBInk`, and launch line `/var/local/kmc/bin/kpm launch koreader --asap`. This is a KPM-based launcher and should **not** be treated as a disposable Zotero cache file. The source of its modification timestamp on 2026-10-11 at 20:31 local time was not established.

## Not yet established

- Broader Kindle compatibility, performance, large-library behavior, and repeatability beyond the successful Oasis smoke test
- Android compatibility
- Behavior with missing files, special characters, network interruptions, and revoked OAuth tokens
- Annotation behavior and long-term synchronization integrity
- Automated functional tests and broader compatibility

**Do not present this as a production release yet.** These are successful manual smoke tests, not comprehensive QA.

The original [Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) and [KOReader](https://github.com/koreader/koreader) authors remain credited. Feature requirements and manual validation: [@vict0rg](https://github.com/vict0rg); implementation assistance: OpenAI ChatGPT (GPT-6).
