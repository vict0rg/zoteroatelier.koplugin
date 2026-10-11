# Zotero Atelier + Dropbox for KOReader

> **Experimental community fork** of [Atelier-Recherche/Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin). This repository is **not** the original project and is not an official Zotero, Dropbox, Amazon, or KOReader product.

## Project purpose

Enable a **Kindle running KOReader after a compatible jailbreak** to browse a personal Zotero library and **open its PDF/EPUB attachments stored in Dropbox**, downloading individual files **on demand** instead of storing the entire library on the Kindle or purchasing Zotero cloud storage.

- **Zotero API:** bibliographic items, collections, and attachment metadata.
- **Dropbox API:** retrieve the corresponding attachment by its Zotero **attachment key**, expected under `storage/ATTACHMENT_KEY/filename.pdf`.
- **KOReader:** display downloaded documents on a jailbroken Kindle. The same experimental feature can first be tested on KOReader for desktop Linux (including Flatpak).
- **Scope:** the personal Zotero library only. Group libraries and bidirectional Dropbox annotation uploads are **not** part of this experiment.

**Development status (11 October 2026):** experimental feature on [`feature/dropbox-on-demand`](https://github.com/vict0rg/zoteroatelier.koplugin/tree/feature/dropbox-on-demand). Dropbox OAuth authorization, opening a personal Zotero PDF, and opening a personal Zotero EPUB have **passed manual tests on Linux Mint / KOReader Flatpak**. After fixing first-time SQLite database initialization, **a Kindle Oasis has successfully synchronized and opened an article and an EPUB book through the Zotero Atelier browser** (manual user test, 11 October 2026). The same Kindle user has **confirmed that locally stored attachments reopen with Wi-Fi switched off**. Independent confirmation of the Dropbox origin of those exact files remains outstanding. This is not a production release; see [manual test results](doc/manual-test-results.md).

**Jailbreak prerequisites:** this project does **not** jailbreak Kindles. Availability depends on the precise Kindle model and firmware. Consult the [KindleModding jailbreak guide](https://kindlemodding.org/jailbreaking/index.html) and the [KOReader official Kindle installation guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices). Always verify compatibility before changing Kindle firmware or installing a jailbreak.

**Testing / implementation:** see [Dropbox development notes](https://github.com/vict0rg/zoteroatelier.koplugin/blob/feature/dropbox-on-demand/doc/dropbox-on-demand.md) in the feature branch. The original Zotero Atelier remains credited and its GPL-3.0 license is preserved. This fork's initial proposal and testing are by [@vict0rg](https://github.com/vict0rg), assisted by OpenAI ChatGPT (GPT-6); the [KOReader Dropbox provider](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua) (KOReader contributors, AGPL-3.0) was used as an architectural reference, without copying its source code.

## First Linux Mint Flatpak smoke test

The experimental branch provides a [backed-up Flatpak installer with rollback](tools/testar_flatpak.sh). It updates **four** plugin code files, leaves existing Zotero metadata and API keys untouched, and does not enable Dropbox until explicitly configured. The initial Linux desktop smoke tests have succeeded; **Kindle Oasis browsing, document opening and offline reopening have passed initial manual tests; broader compatibility tests remain**.

## Dropbox on-demand: getting started and offline use

**Read first:** [Step-by-step guide in Portuguese (Linux Mint + Kindle Oasis)](doc/guia-kindle-dropbox-pt-BR.md) · [Technical notes and OAuth setup](doc/dropbox-on-demand.md) · [Manual test results](doc/manual-test-results.md).

1. **Install** the `feature/dropbox-on-demand` version of Zotero Atelier and restart KOReader. For Linux Mint Flatpak, use [the backup-enabled test installer](tools/testar_flatpak.sh); on Kindle, copy the entire `zoteroatelier.koplugin` directory (including `zotero_dropbox.lua`) to the actual KOReader plugin directory.
2. **Configure Zotero** with your personal user ID and API key, then run **Zotero Atelier → Synchronize** on *each* device. The metadata/collections database is local to each device; transferring credential files alone does not copy the previously synchronized database.
3. **Configure Dropbox** under **Zotero Atelier → Settings → Configure Dropbox account**, specifying the Dropbox App key and the **remote** Zotero storage root (for example `/Research/Zotero/storage`, never a Linux `/home/...` directory). Authorize with the built-in QR code and one-time code; verify `Authorization saved: yes` and `On-demand downloads: enabled`.
4. **Open an attachment** from a Zotero reference while connected to Wi-Fi. If it is not already present on the device, the plugin downloads **only the selected PDF or EPUB** from Dropbox to `<KOReader data directory>/zotero/storage/<ATTACHMENT_KEY>/<FILENAME>`. It does **not** stream the document from Dropbox.
5. **Reopen offline:** the normal attachment-opening path checks for the locally cached file *before* requesting internet access. A completed download remains on the device until the user deletes the file/cache or the storage is otherwise cleared. **Offline reopening on Kindle Oasis is confirmed by a manual test**: previously opened files were found in local `storage` and reopened with Wi-Fi disabled. The downloaded file can also be located with KOReader's file browser. Newly requested files and metadata/annotation synchronization still require connectivity.

**First-sync progress (experimental):** the latest branch displays a persistent, non-dismissible progress panel with the actual **collections/items X/Y**, per-stage percentages, and **attachment X/Y**. The most recent phase is written to `<KOReader data directory>/zotero/sync_status.txt` without credentials. These are *stage percentages*, not an overall ETA or live transfer speed. The updated synchronization interface has **been exercised on Kindle Oasis**, but still needs broader error-handling and long-running transfer tests. For an existing USB-installed Kindle plugin, the [two-file backup-enabled progress updater](tools/atualizar_progresso_kindle.sh) preserves the library database and personal credentials. Never update plugin code while KOReader is running.

**Optional:** Zotero Atelier supports marking collections with **Download this collection during sync**, which requests batch downloads during a future synchronization; it consumes device space and requires internet. The Dropbox fallback participates in that download routine for supported imported attachments. Test on a small collection first.

**Scope and safety:** Dropbox access is read-only (`files.content.read`); neither the PDFs nor EPUBs are uploaded back to Dropbox. The feature currently expects Zotero `imported_file`/`imported_url` entries stored as `storage/ATTACHMENT_KEY/FILENAME`; it does not resolve arbitrary `linked_file` attachments. Do not share `meta.lua` or `dropbox_atelier.lua`: they contain credentials. Disable **Write highlights into PDF files** during initial testing, and do not assume annotation syncing works offline.

## Kindle Oasis: show Zotero books in the documents cover mosaic (experimental)

**Optional Kindle-only layout introduced after the initial tests:** new downloads go to `/mnt/us/documents/Zotero/storage/<ATTACHMENT_KEY>/<FILENAME>` so KOReader's file browser can show the EPUB/PDF covers when recursive subfolder viewing is enabled. The personal Zotero SQLite database, settings, OAuth tokens and synchronization diagnostics remain in `/mnt/us/koreader/zotero/`. **Flatpak/Linux desktop still uses the previous `<data directory>/zotero/storage/` layout.**

To update an already working Kindle, **fully exit KOReader**, connect it to Linux by USB, then use the [safe Kindle documents migration script](tools/mover_storage_para_documents_kindle.sh). It backs up the previous `zoteroapi.lua` and SQLite files, moves the entire old storage directory into `documents/Zotero/storage` on the same Kindle filesystem (including sidecars), and installs the updated code. It aborts without merging if the old and new storage directories both already exist. No PDF or EPUB file is sent to GitHub.

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/mover_storage_para_documents_kindle.sh \
  -o ~/Downloads/mover_storage_para_documents_kindle.sh \
  && bash ~/Downloads/mover_storage_para_documents_kindle.sh
```

**Verification of this new layout on a physical Kindle is still pending.** The original Kindle offline tests passed with the previous layout; moving reading files changes their absolute paths, so recently-opened-book shortcuts may require reopening from the new directory. A reported KOReader navigation freeze/hard reset has not yet been diagnosed; changing the file location is a usability improvement, **not a proven crash fix**.

### Repairing Kindle with split Zotero storage after initial migration

If the old `/mnt/us/koreader/zotero/storage` and new `/mnt/us/documents/Zotero/storage` **both contain attachments**, do not rerun the original one-time migration script and do not delete the old folder. An observed Kindle test showed three PDFs/EPUBs (14 MB) in the new storage and one (616 KiB) still under the old storage path. The installed plugin still used an exact Zotero data directory comparison, which is now replaced in the repository by KOReader's `Device:isKindle()` detection.

With KOReader fully closed and USB mounted, run the [no-overwrite split-storage repair](tools/corrigir_storage_duplo_kindle.sh). It backs up the previous API module and SQLite database; aborts before touching files if attachment key directories collide; installs only `zoteroapi.lua`; moves unmatched entire Zotero attachment key folders (including `.sdr`) without merging/overwriting; and leaves Dropbox credentials and Flatpak unchanged. **The repair is published but has not yet passed a device test.**

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/corrigir_storage_duplo_kindle.sh \
  -o ~/Downloads/corrigir_storage_duplo_kindle.sh \
  && bash ~/Downloads/corrigir_storage_duplo_kindle.sh
```


## Disk usage and opt-in deletion of Zotero downloads (experimental)

A new **Zotero Atelier → Maintenance → Zotero storage and cleanup** dialog shows the device's total/available space and the size/count of **locally cached Zotero PDF/EPUB attachments**, broken down by the current download folder and a separate legacy folder if present. All selection checkboxes begin **unchecked**. The user must select a category, press **Delete selected downloads**, then accept a second confirmation. Actual disk reclamation is estimated from individual file sizes (filesystem allocation may differ).

Only files that **exactly match imported Zotero attachment metadata** and are located under the plugin's own download roots are eligible. No recursive `rm -rf` is used, and SQLite references, Zotero/Dropbox credentials, `.sdr` reading settings, and the global KOReader `cr3cache` are never deleted. Files may be retrieved from Dropbox again when online.

For the Kindle, fully exit KOReader and use the [backup-enabled storage panel installer](tools/instalar_gerenciador_espaco_kindle.sh), which updates `main.lua` and installs `zotero_storage_manager.lua` without touching any documents. **This dialog is implemented but not yet validated on a physical Kindle; do not install it solely to troubleshoot the previously reported navigation freeze.**

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/instalar_gerenciador_espaco_kindle.sh \
  -o ~/Downloads/instalar_gerenciador_espaco_kindle.sh \
  && bash ~/Downloads/instalar_gerenciador_espaco_kindle.sh
```

The general Kindle update script now includes all three necessary code files (`main.lua`, `zoteroapi.lua`, and `zotero_storage_manager.lua`) to prevent missing-module errors.

## Fixing a bogus nine-byte PDF on Kindle (experimental repair)

One Kindle test revealed an attachment named `.pdf` which contained just **9 bytes of ASCII text**, while the original PDF from Dropbox was **5,052,243 bytes**. The Zotero Storage fallback had been writing HTTP responses straight into the final file, including possible error messages. The new branch validates PDF/EPUB headers before using cached attachments and downloads via a temporary file, rejecting bad responses; Dropbox on-demand is validated as well. This is a **header sanity check, not a full PDF/EPUB integrity verifier**.

A [backup-enabled Kindle code-only hotfix](tools/corrigir_download_pdf_kindle.sh) installs `zoteroapi.lua`, `zotero_dropbox.lua`, and `zotero_file_validation.lua`. It **does not delete, move or repair documents** and **does not affect Flatpak**. The original bad file should be backed up and replaced with a verified original separately, preserving KOReader `.sdr` reading state. **This hotfix still needs on-device validation**.

## Original Zotero Atelier documentation

This fork preserves the upstream Zotero Atelier functionality and attribution. See also the [original project](https://github.com/Atelier-Recherche/zoteroatelier.koplugin), the [English reference documentation](README.en.md), and the [preserved French documentation](README.fr.md).

---

# Original Zotero Atelier: features and usage

[KOReader](https://github.com/koreader/koreader) plugin to browse your Zotero library, open attachments, annotate (PDF / EPUB), and sync notes with Zotero — including when files are not on WebDAV.

> [!NOTE]
> Continued as **Zotero Atelier** (fork / continuation of the Zotero KOReader plugin). Beta: bug reports and PRs welcome.

French original: [README.fr.md](README.fr.md)

## Features

* Sync via Zotero Web API
* Open PDF / EPUB / HTML attachments
* Bidirectional annotation sync (create, update, delete)
* Write highlights **into the PDF** (toggle) and/or sync to Zotero
* **EPUB** annotations (KOReader sidecar ↔ Zotero; approximate position / xpointers)
* **Document annotations** panel (filter, jump to page, delete)
* **Global search** across annotations in the local library
* Auto-download for offline collections
* **WebDAV** storage
* **Local files** without WebDAV: linked-files folder, external Zotero storage, path mappings, basename search, search roots
* Search entries by title and first author

### Limitations

* Bibliographic search is still basic (no full tags / DOI / all authors yet)
* EPUB exact CFI positioning may be imperfect; text, note, and page/chapter sync first
* Enabling both in-PDF writing and Zotero sync can show duplicate highlights depending on the viewer

## Installation

1. Use a recent KOReader build
2. Install the plugin folder (name **must** end with `.koplugin`)
3. **Fully quit and restart** KOReader
4. Create an API key in [Zotero Settings](https://www.zotero.org/settings/keys)
5. Configure WebDAV if needed
6. Enter credentials in the plugin menu or edit the config file

### Where to copy the plugin

The directory **must** be named exactly `zoteroatelier.koplugin`:

```
zoteroatelier.koplugin/
├── _meta.lua
├── main.lua
├── zoteroapi.lua
├── annotations.lua
├── annotation_panel.lua
├── annotation_search.lua
└── …
```

| Platform | Typical path |
|----------|----------------|
| PC / Kobo / Kindle | `<KOReader install>/plugins/zoteroatelier.koplugin` |
| **Android** | `/sdcard/koreader/plugins/zoteroatelier.koplugin` |
| Alternative | `<KOReader data directory>/plugins/zoteroatelier.koplugin` |

Migrating from `zotero.koplugin`: rename/replace the folder and restart. Local data stays in `<KOReader data>/zotero/` for compatibility.

### Finding the plugin in KOReader

- Top menu → **Search** → **Zotero Atelier**, or **Tools** → **Zotero Atelier**
- Local files: Zotero Atelier → **Settings** → **Local files**
- Enable/disable: Settings → **Plugin management** → **User plugins** → **Zotero Atelier**

## Usage

Most library metadata stays on device. Apart from **Synchronize** (and downloading a missing file), the plugin avoids hitting the Zotero server.

### Browse / Synchronize / Maintenance

Same workflow as before: browse collections, incremental sync, re-analyze / rescan / full resync.

### Annotations & notes

| Menu item | Role |
|-----------|------|
| **Document annotations** | Filterable list for the open document |
| **Search annotations** | Search all synced annotations |
| **Sync document annotations** | Immediate create/update/delete for the open file |
| **Write highlights into PDF files** | Enable writing highlights into the PDF |

Annotation sync also runs on open/close when the file matches a Zotero attachment.

### Local files

For PDFs not on Zotero storage / WebDAV: linked-files base, external storage (`storage/KEY/file`), path mappings, search roots, basename fallback, allow stale local files.

## Configuration

Edit `<KOReader data>/zotero/meta.lua` (see French README for the full key list). WebDAV URL must point to a directory named `zotero`.

By default Zotero Atelier **enables** writing highlights into PDFs opened from the browser; turn that off in plugin settings if you prefer sidecar/Zotero only.

## Credits

Based on the community Zotero KOReader plugin and subsequent forks.  
**Zotero Atelier** — continued development (annotations, notes, local files).
