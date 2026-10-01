# translate

`translate` is a native macOS command-line translator powered by Apple’s on-device Translation framework.

Translate a sentence from your shell, pipe the result into another command, and keep the text on your Mac.

```sh
translate "Good morning" -nl
```

## Requirements

- macOS 26 or later
- Xcode 26.2 or later to build from source
- Downloaded translation models for the language pair you want to use

The app does not use a third-party translation API. Apple’s translation models must be installed before a language pair can translate.

## Installation

Build the release executable from a checkout of this repository:

```sh
swift build -c release
```

Run it directly:

```sh
.build/release/translate "Good morning" -nl
```

Or install it somewhere on your `PATH`:

```sh
install -m 755 .build/release/translate /usr/local/bin/translate
```

## Usage

Translate using a language name:

```sh
translate "my string" to Dutch
```

Or use a language code:

```sh
translate "my string" -nl
```

The source language is detected locally from the supplied text. The translated text is written to standard output, so it works naturally with pipelines:

```sh
translate "Good morning" -nl | pbcopy
```

### Available languages

Show the languages supported by the installed version of macOS:

```sh
translate -available
```

The command prints one `language-code<TAB>language-name` entry per line. A language in this list is supported by the framework, but its model may not yet be downloaded. Download and manage models in the Translate app, then run the command again.

### Target formats

`translate` accepts common English language names and BCP 47 language identifiers:

```sh
translate "Where is the station?" to German
translate "Where is the station?" -de
translate "Olá" -pt-BR
```

## How it works

The command uses `NLLanguageRecognizer` to identify the source language, checks the language pair with `LanguageAvailability`, and translates through Apple’s `TranslationSession`. It never sends the requested text to a separate web service.

For Apple’s current model availability rules, see [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability).

## Development

```sh
swift test
swift build -c release
swiftlint --strict Sources Tests Package.swift
```

## Releases

Publishing a GitHub release automatically updates the `translate` formula in [0xWDG/homebrew-tap](https://github.com/0xWDG/homebrew-tap). Before publishing a release, add a `HOMEBREW_TAP_TOKEN` Actions secret to this repository. The token needs **Contents: Read and write** access to `0xWDG/homebrew-tap`; use a fine-grained personal access token limited to that repository.

## Limitations

- Translation quality and supported languages are determined by the version of macOS and the models Apple provides.
- Very short or ambiguous text may not provide enough context for local source-language detection.
- The required model must be downloaded before a language pair can translate.
