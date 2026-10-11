# Zotero Atelier + Dropbox for KOReader

> **Experimental community fork** of [Atelier-Recherche/Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin). This repository is **not** the original project and is not an official Zotero, Dropbox, Amazon, or KOReader product.

## Project purpose

Enable a **Kindle running KOReader after a compatible jailbreak** to browse a personal Zotero library and **open its PDF/EPUB attachments stored in Dropbox**, downloading individual files **on demand** instead of storing the entire library on the Kindle or purchasing Zotero cloud storage.

- **Zotero API:** bibliographic items, collections, and attachment metadata.
- **Dropbox API:** retrieve the corresponding attachment by its Zotero **attachment key**, expected under `storage/ATTACHMENT_KEY/filename.pdf`.
- **KOReader:** display downloaded documents on a jailbroken Kindle. The same experimental feature can first be tested on KOReader for desktop Linux (including Flatpak).
- **Scope:** the personal Zotero library only. Group libraries and bidirectional Dropbox annotation uploads are **not** part of this experiment.

**Development status (11 October 2026):** experimental feature on [`feature/dropbox-on-demand`](https://github.com/vict0rg/zoteroatelier.koplugin/tree/feature/dropbox-on-demand). Dropbox OAuth authorization, opening a personal Zotero PDF, and opening a personal Zotero EPUB have **passed manual tests on Linux Mint / KOReader Flatpak**. The plugin has also been copied to a Kindle Oasis, but opening attachments and offline reopening **have not yet been confirmed on the Kindle**. This is not a production release; see [manual test results](doc/manual-test-results.md).

**Jailbreak prerequisites:** this project does **not** jailbreak Kindles. Availability depends on the precise Kindle model and firmware. Consult the [KindleModding jailbreak guide](https://kindlemodding.org/jailbreaking/index.html) and the [KOReader official Kindle installation guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices). Always verify compatibility before changing Kindle firmware or installing a jailbreak.

**Testing / implementation:** see [Dropbox development notes](https://github.com/vict0rg/zoteroatelier.koplugin/blob/feature/dropbox-on-demand/doc/dropbox-on-demand.md) in the feature branch. The original Zotero Atelier remains credited and its GPL-3.0 license is preserved. This fork's initial proposal and testing are by [@vict0rg](https://github.com/vict0rg), assisted by OpenAI ChatGPT (GPT-6); the [KOReader Dropbox provider](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua) (KOReader contributors, AGPL-3.0) was used as an architectural reference, without copying its source code.

## First Linux Mint Flatpak smoke test

The experimental branch provides a [backed-up Flatpak installer with rollback](tools/testar_flatpak.sh). It updates **four** plugin code files, leaves existing Zotero metadata and API keys untouched, and does not enable Dropbox until explicitly configured. The initial Linux desktop smoke tests have succeeded; **Kindle compatibility is still being tested**.

## Dropbox on-demand: getting started and offline use

**Read first:** [Step-by-step guide in Portuguese (Linux Mint + Kindle Oasis)](doc/guia-kindle-dropbox-pt-BR.md) · [Technical notes and OAuth setup](doc/dropbox-on-demand.md) · [Manual test results](doc/manual-test-results.md).

1. **Install** the `feature/dropbox-on-demand` version of Zotero Atelier and restart KOReader. For Linux Mint Flatpak, use [the backup-enabled test installer](tools/testar_flatpak.sh); on Kindle, copy the entire `zoteroatelier.koplugin` directory (including `zotero_dropbox.lua`) to the actual KOReader plugin directory.
2. **Configure Zotero** with your personal user ID and API key, then run **Zotero Atelier → Synchronize** on *each* device. The metadata/collections database is local to each device; transferring credential files alone does not copy the previously synchronized database.
3. **Configure Dropbox** under **Zotero Atelier → Settings → Configure Dropbox account**, specifying the Dropbox App key and the **remote** Zotero storage root (for example `/Research/Zotero/storage`, never a Linux `/home/...` directory). Authorize with the built-in QR code and one-time code; verify `Authorization saved: yes` and `On-demand downloads: enabled`.
4. **Open an attachment** from a Zotero reference while connected to Wi-Fi. If it is not already present on the device, the plugin downloads **only the selected PDF or EPUB** from Dropbox to `<KOReader data directory>/zotero/storage/<ATTACHMENT_KEY>/<FILENAME>`. It does **not** stream the document from Dropbox.
5. **Reopen offline:** the normal attachment-opening path checks for the locally cached file *before* requesting internet access. A completed download remains on the device until the user deletes the file/cache or the storage is otherwise cleared. Offline reopening on **Kindle Oasis is still unverified**: test it by opening a document once online, disabling Wi-Fi and reopening it from Zotero Atelier. The downloaded file can also be located with KOReader's file browser. Newly requested files and metadata/annotation synchronization still require connectivity.

**Optional:** Zotero Atelier supports marking collections with **Download this collection during sync**, which requests batch downloads during a future synchronization; it consumes device space and requires internet. The Dropbox fallback participates in that download routine for supported imported attachments. Test on a small collection first.

**Scope and safety:** Dropbox access is read-only (`files.content.read`); neither the PDFs nor EPUBs are uploaded back to Dropbox. The feature currently expects Zotero `imported_file`/`imported_url` entries stored as `storage/ATTACHMENT_KEY/FILENAME`; it does not resolve arbitrary `linked_file` attachments. Do not share `meta.lua` or `dropbox_atelier.lua`: they contain credentials. Disable **Write highlights into PDF files** during initial testing, and do not assume annotation syncing works offline.

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
