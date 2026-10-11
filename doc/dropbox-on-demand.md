# Experimental Dropbox attachment access (read-only)

**Status:** untested proof of concept. Do not deploy to a production KOReader installation without backups. Personal Zotero library only; no Zotero Groups or Dropbox annotation upload.

## Goal

Keep Zotero personal-library metadata synchronized through the Zotero API, while storing personal PDF attachments in Dropbox rather than paid Zotero Storage. When a user opens an `imported_file` or `imported_url` attachment, Zotero Atelier:

1. Checks its already supported local paths.
2. If absent, optionally downloads **one file** from Dropbox into the existing KOReader cache.
3. If unavailable in Dropbox, preserves the original Zotero Storage / WebDAV behavior.

It expects a Dropbox path of the form `/YOUR/REMOTE/STORAGE/<ZOTERO_ATTACHMENT_KEY>/<FILENAME>`. The attachment key is **not** the parent bibliographic item's key. A successful Zotero metadata synchronization does not establish whether the Dropbox path exists.

## Configure Dropbox

1. Create a Dropbox developer app via <https://www.dropbox.com/developers/apps>. For an existing Dropbox tree, select **Scoped access → Full Dropbox** and request **only** `files.content.read`. This grants access to read files throughout the Dropbox account (even though this plugin never uploads), so use a dedicated revocable app and consider the security implications.
2. Obtain an OAuth **offline refresh token** using PKCE (for public/native applications, without embedding any app secret). The helper `tools/configurar_dropbox_oauth.py` prompts for your app key and remote root, opens Dropbox authorization, and stores the refresh token locally.
3. The helper creates `<KOReader data directory>/zotero/dropbox_atelier.lua` as a local secret (permissions 0600):

```lua
return {
    enabled = true,
    app_key = "YOUR_DROPBOX_APP_KEY",
    refresh_token = "YOUR_REFRESH_TOKEN",
    storage_root = "/YOUR/DROPBOX/PATH/TO/storage",
}
```

**Never commit that configuration, the Zotero `meta.lua`, or any secrets.** On Linux Mint Flatpak the default KOReader data directory is `~/.var/app/rocks.koreader.KOReader/config/koreader`. On Kindle it is `koreader` on the device. Both are separate and need separately secured settings.

Refresh tokens are stored **on the device**, not in this repository, and the module only calls Dropbox token refresh and `/2/files/download`. Dropbox itself documents OAuth/PKCE at <https://developers.dropbox.com/oauth-guide>.

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
