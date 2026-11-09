# TiXun

English · [简体中文](README.md)

**Understand a question. Practise until you can solve it yourself.**

TiXun is an open-source learning app for Android and Linux. Ask AI for help, keep your notes and mistakes, then check your understanding through practice and spaced review.

No TiXun account is needed. Your learning data stays on your device. Saved material and existing exercises work offline; AI requests need an internet connection and your own provider API key.

## Get the app

Download the latest package from [GitHub Releases](https://github.com/mumu-lhl/tixun/releases/latest):

- **Android 10 or later:** install the `android-release.apk` attachment.
- **Linux x86_64:** extract the `linux-x64.tar.gz` attachment and run `./tixun`. Keep its `lib` and `data` folders alongside the executable. GTK 3 and an unlocked Secret Service keyring are required for the desktop app and secure key storage.

Packages use Release build mode. The published v0.5.2 Android package uses a development key; the main branch configures a stable release key for future builds. Back up your data before the first signature change, then uninstall the old package, install and restore. Later builds with the same signing key can update in place. Physical Android device checks and real provider acceptance tests are still pending.

## Start learning

1. Open Settings, choose a provider, save your API key and test the connection. DeepSeek Flash accepts images; DeepSeek V4 Pro is text-only. OpenAI-compatible services can use a custom URL, model and declared capabilities.
2. Ask a question or attach an image. Guided teaching offers hints and lets you try; switch to direct answers when you want the complete explanation.
3. Save useful knowledge or a mistake from the conversation. Keep the original image, your answer and your own explanation.
4. Answer a practice question before viewing its solution. Review tasks are scheduled from actual answers, rather than from reading explanations.

AI answers and generated questions can be wrong. Check important results; unchecked AI reference answers do not count as verified mastery evidence.

## New on the main branch

These settings are not included in the published v0.5.2 package yet:

- **Chinese and English:** select either language or follow the system under Settings → Appearance. Existing notes, conversations and custom prompts retain their original content.
- **Dynamic colors:** use Android 12+ wallpaper colors or a supported Linux desktop accent. TiXun falls back to its default palette when system colors are unavailable. Light and dark themes remain available.
- **Reasoning effort:** set a global default in Settings or override it for one conversation using the reasoning button. DeepSeek and ChatGPT plan requests support reasoning with tools. Quiz preparation enables the configured effort for that conversation; compatible providers follow their configured capabilities. Your global preference is preserved.
- **Prompt management:** edit, search, preview and reset prompts for teaching and study tasks under Settings → Prompts. Changes apply to future requests. Application permissions and answer-submission rules remain in force.

**ChatGPT plan sign-in** is also available on the main branch, outside the published v0.5.2 package. Open Settings → ChatGPT plan → **Continue with ChatGPT**. Complete authorization in your system browser, return to TiXun, select a model and choose **Use this account and model**. Available models and allowance depend on the permissions granted by your account. Requests never fall back to API billing.

You can switch accounts, authorize again, sign out or restore your previous API settings. Tokens stay in system secure storage and are excluded from backups; another device needs a fresh sign-in. Image input is off unless the catalog declares support or you confirm it from model documentation. Protocol and isolated GUI tests pass; **real Plus/Pro account and physical Android acceptance checks remain pending**. See [integration details](docs/CHATGPT_PROVIDER.md).

## Keep your data safe

Use Settings → Backup to export your database, images, notes, conversations and practice history. API keys are excluded. Restore requires checking the backup before it replaces the active data; a recovery copy is retained.

Only the conversation and material needed for an AI request are sent to the chosen provider. TiXun does not automatically upload your entire library or collect analytics. Keys use system secure storage and are never silently saved as plain text.

[Report a problem](https://github.com/mumu-lhl/tixun/issues) · [Development guide](DEVELOPMENT.md) · [Project status](ROADMAP.md)

## Nightly builds

[Daily prereleases](https://github.com/mumu-lhl/tixun/releases?q=nightly&expanded=true) build the default branch at 20:30 UTC, subject to GitHub scheduling and successful verification. Each has an independent timestamp tag, a signed Release APK, a Linux Release bundle and checksums. Nightlies do not replace the stable Latest release and may contain unfinished changes. Only the latest successful nightly is retained; publishing a new one removes older nightly releases, assets and tags.

Future stable and nightly Android releases include `arm64-v8a`, `armeabi-v7a`, `x86_64`, and `universal` APKs. Most modern phones use arm64-v8a; choose Universal if unsure. All variants share the same application ID, version code and signing key. Existing v0.5.2 assets are unchanged.

## Reasoning and handwritten drafts

Chat replies stream incrementally. Enable reasoning to view provider-returned reasoning or public summaries in a collapsed panel. ChatGPT encrypted internal state is never decoded or displayed. Exercise-generation reasoning stays hidden until the current questions are submitted; reasoning is not proof that an answer is correct. Saved questions and AI-sourced study material link back to the same reasoning record.

Chat sessions, mistakes and practice questions each have a Scratchpad button. Every scratchpad supports multiple pages, colored pens with adjustable width, a radius eraser, undo/redo, page navigation and confirmed deletion. The canvas can pan in any direction. Switch to pan/zoom mode for touch gestures or the Linux mouse wheel; Reset view preserves the ink. Pages and view positions save locally, survive reopening and are included in full backups. They are not automatically sent to AI. Permanently deleting the owner also deletes its scratchpad.

### Exam records

Open Exam records from Study, select a calendar date and add an exam and its subjects. Chinese, mathematics and English use raw scores only; other subjects may also record scaled scores. Unknown marks can stay blank.

Store exam papers, answer sheets and reference answers separately. Android supports camera and photo selection; Linux supports file selection. Original images stay local and are included in complete backups.

The question breakdown supports questions and subquestions. Next question and Next subquestion number entries, focus marks and reuse the previous sibling's maximum. Questions with subquestions use their child totals. Blank means unknown; `0` means zero marks. Totals never overwrite the exam's raw score.

AI extraction uploads only 1–4 selected photos, up to 20 MB combined, to a vision-capable model. Prefer teacher-awarded marks and review every suggestion before saving. Saving replaces the previous breakdown. Reasoning strength is configurable for this request; its prompt is editable in Prompt manager. Mock mode supports manual entry and does not pretend to grade photos.
