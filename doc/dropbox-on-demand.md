# Experimental Dropbox attachment access (read-only)

**Status (2026-10-11):** experimental, with **Dropbox OAuth, a PDF download/open, and an EPUB download/open manually confirmed on Linux Mint / KOReader Flatpak**. The feature has been copied to a Kindle Oasis, but successful attachment opening and offline reopening **have not yet been confirmed on the Kindle**. Keep backups; personal Zotero library only; no Zotero Groups or Dropbox annotation upload. See the [Portuguese setup and offline-use guide](guia-kindle-dropbox-pt-BR.md) and [test record](manual-test-results.md).

## Goal

Keep Zotero personal-library metadata synchronized through the Zotero API, while storing personal PDF attachments in Dropbox rather than paid Zotero Storage. When a user opens an `imported_file` or `imported_url` attachment, Zotero Atelier:

1. Checks its already supported local paths.
2. If absent, optionally downloads **one file** from Dropbox into the existing KOReader cache.
3. If unavailable in Dropbox, preserves the original Zotero Storage / WebDAV behavior.

It expects a Dropbox path of the form `/YOUR/REMOTE/STORAGE/<ZOTERO_ATTACHMENT_KEY>/<FILENAME>`. The attachment key is **not** the parent bibliographic item's key. A successful Zotero metadata synchronization does not establish whether the Dropbox path exists.

## Configure Dropbox directly inside Zotero Atelier

**Only one KOReader plugin is required.** In the experimental version, open:

`Zotero Atelier → Settings → Configure Dropbox account`

1. Visit <https://www.dropbox.com/developers/apps> in a normal browser and create a **Scoped access / Full Dropbox** developer app. Under Permissions select **files.content.read only**. You do **not** need to install the KOReader cloud-storage Dropbox plugin.
2. In **Dropbox app and storage folder**, enter the Dropbox **App key** (never the App secret), plus the cloud folder that contains Zotero's attachment-key folders, e.g. `/Research/Zotero/storage` — this is a path **inside Dropbox**, not `~/Dropbox/...` on Linux.
3. Choose **Authorize Dropbox (QR code)** in the same Zotero Atelier menu. Scan the QR code using your phone, or use a browser capable of opening the generated authorization URL.
4. Sign in to Dropbox, approve the *read-only* permission, and copy the authorization code that Dropbox displays.
5. Back in KOReader, choose **Enter Dropbox authorization code**, paste or type the code and tap **Connect**. The plugin exchanges it using OAuth PKCE (**S256**) and stores a renewable token locally.
6. Confirm **Dropbox connection status** displays “Authorization saved: yes” and “On-demand downloads: enabled”. Then test by opening **one** previously unavailable Zotero PDF/EPUB.

Do not publish Dropbox refresh tokens, authorization codes, Zotero API keys, or full credential files in screenshots, chat messages or GitHub commits. The Dropbox App key is a public OAuth client identifier, but avoid exposing entire settings files. The generated authorization QR code is temporary. A different device (e.g. Kindle) must be configured separately or receive its protected credential file through a carefully controlled manual transfer.

Dropbox official OAuth documentation: <https://docs.dropboxapi.com/dropbox-api/docs/oauth>.

The first-stage standalone `tools/configurar_dropbox_oauth.py` helper is **optional**, retained for developers; it is no longer required for end users.


## Where downloads go; whether they work offline

The feature is **download-and-cache**, not streaming. For an attachment of a supported `imported_file`/`imported_url` type, the plugin saves the Dropbox response via a temporary `.dropbox-part` file and renames the completed file to:

```text
<KOReader data directory>/zotero/storage/<ZOTERO_ATTACHMENT_KEY>/<FILENAME>
```

The Zotero browser first tries `API.tryResolveLocalAttachment`, which checks local files and the cache, **before** entering its network-only fallback. A successfully downloaded, current local file should reopen without Wi-Fi. The downloaded file is retained on storage until deleted/cleaned or otherwise invalidated; no automatic deletion has been added by this integration. If file version checks reject the cache or the file is missing, a new download may be necessary. **Actual offline reopen on the Kindle is still a test to complete.**

Important distinctions:

- `Synchronize` updates the **local metadata database** and optionally downloads attachments belonging to collections explicitly marked **Download this collection during sync**. It does not download all attachments by default.
- The metadata database and attachment cache are **per device**. Copying `meta.lua` and `dropbox_atelier.lua` from Flatpak to a Kindle transfers **configuration/credentials**, not the prior metadata sync or downloaded documents. Run `Synchronize` on the Kindle to populate its database.
- Zotero annotation synchronization is separate and requires internet. Dropbox receives no uploads. During first trials disable **Write highlights into PDF files**.
- To check offline use: open a PDF/EPUB online, close it, disable Kindle Wi-Fi, and reopen **the same file** through Zotero Atelier. The KOReader file browser can also locate the actual local cached file.

## Safety

- Preserve the upstream GPLv3 license and authorship.
- Default is **disabled** if no `dropbox_atelier.lua` configuration exists.
- Turn off **Zotero Atelier → Settings → Write highlights into PDF files** to avoid modifying your local PDFs. Use a **read-only Zotero API key** for initial testing.
- The optional fallback downloads files to the existing KOReader cache; this is not bidirectional annotation synchronization.
- Confirm whether your Dropbox contains the actual Zotero `storage/KEY/FILENAME` directory tree. The feature does **not** recursively search Dropbox.
- Downloads and file opening have **passed on Linux Mint / KOReader Flatpak**. Kindle Oasis and Android attachment opening, offline reopening and error-handling **remain unverified**.
- Failure in Dropbox access can be logged and followed by the existing Zotero Storage lookup, which can still yield HTTP 404 if there is no remote Zotero copy.
- Do not publish file paths containing secrets in logs/screenshots.

## Credits / licensing

- **Original plugin and contributors:** [Atelier-Recherche / Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) — GPL-3.0. All existing upstream copyright and attribution remain intact.
- **Background / design reference:** [KOReader Cloud Storage Dropbox provider](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua) — KOReader contributors, AGPL-3.0. No code has been copied from the KOReader implementation; this new module is independently written against the public Dropbox API v2.
- **Feature proposal, requirements, testing:** [@vict0rg](https://github.com/vict0rg).
- **Programming assistance:** OpenAI ChatGPT (GPT-6), acknowledged as assistance rather than as copyright owner.

Source changes are provided for review under the repository's GPLv3 terms. Do not merge until reviewed and tested by maintainers.
