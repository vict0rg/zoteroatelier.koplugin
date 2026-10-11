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

## Not yet established

- Kindle Oasis / jailbroken Kindle compatibility and performance
- Android compatibility
- Offline reopen after first download
- Behavior with missing files, special characters, network interruptions, and revoked OAuth tokens
- Annotation behavior and long-term synchronization integrity
- Automated functional tests and broader compatibility

**Do not present this as a production release yet.** These are successful manual smoke tests, not comprehensive QA.

The original [Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin) and [KOReader](https://github.com/koreader/koreader) authors remain credited. Feature requirements and manual validation: [@vict0rg](https://github.com/vict0rg); implementation assistance: OpenAI ChatGPT (GPT-6).
