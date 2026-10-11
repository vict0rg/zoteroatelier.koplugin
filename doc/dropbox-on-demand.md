# Experimental Dropbox attachment access (read-only)

**Status:** untested proof of concept. Do not deploy to a production KOReader installation without backups. Personal Zotero library only; no Zotero Groups or Dropbox annotation upload.

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

No Dropbox API keys, refresh tokens, or authorization codes should ever be included in screenshots, chat messages or GitHub commits. The generated authorization QR code is temporary. A different device (e.g. Kindle) must be configured separately or receive its protected credential file through a carefully controlled manual transfer.

Dropbox official OAuth documentation: <https://docs.dropboxapi.com/dropbox-api/docs/oauth>.

The first-stage standalone `tools/configurar_dropbox_oauth.py` helper is **optional**, retained for developers; it is no longer required for end users.


## Safety

- Preserve the upstream GPLv3 license and authorship.
- Default is **disabled** if no `dropbox_atelier.lua` configuration exists.
- Turn off **Zotero Atelier → Settings → Write highlights into PDF files** to avoid modifying your local PDFs. Use a **read-only Zotero API key** for initial testing.
- The optional fallback downloads files to the existing KOReader cache; this is not bidirectional annotation synchronization.
- Confirm whether your Dropbox contains the actual Zotero `storage/KEY/FILENAME` directory tree. The feature does **not** recursively search Dropbox.
- Cache files and network transfers have **not** yet been tested on Kindle Oasis or Android.
- Failure in Dropbox access can be logged and followed by the existing Zotero Storage lookup, which can still yield HTTP 404 if there is no remote Zotero copy.
- Do not publish file paths containing secrets in logs/screenshots.

## Credits / licensing

- **Original plugin and contributors:** [Atelier-Recherche / Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) — GPL-3.0. All existing upstream copyright and attribution remain intact.
- **Background / design reference:** [KOReader Cloud Storage Dropbox provider](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua) — KOReader contributors, AGPL-3.0. No code has been copied from the KOReader implementation; this new module is independently written against the public Dropbox API v2.
- **Feature proposal, requirements, testing:** [@vict0rg](https://github.com/vict0rg).
- **Programming assistance:** OpenAI ChatGPT (GPT-6), acknowledged as assistance rather than as copyright owner.

Source changes are provided for review under the repository's GPLv3 terms. Do not merge until reviewed and tested by maintainers.
