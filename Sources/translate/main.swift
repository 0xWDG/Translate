//
//  main.swift
//  Translate
//
//  Created by Wesley de Groot on 2026-10-01.
//  https://wesleydegroot.nl
//
//  https://github.com/0xWDG/Translate
//  MIT License
//
import Foundation
import NaturalLanguage
import Translation

/// A terminal interface to the on-device translation models supplied by macOS.
@main
struct TranslateCommand {
    /// Runs the command using arguments supplied by the shell.
    static func main() async {
        do {
            let command = try CommandInvocation(arguments: Array(CommandLine.arguments.dropFirst()))
            switch command {
            case let .translate(request):
                let translation = try await Translator().translate(request)
                print(translation)
            case .available:
                print(await AvailableLanguageReporter().report())
            }
        } catch let error as CommandError {
            fputs("translate: \(error.localizedDescription)\n", stderr)
            if error.shouldShowUsage {
                fputs("\(TranslationRequest.usage)\n", stderr)
            }
            Foundation.exit(error.exitCode)
        } catch {
            fputs("translate: \(error.localizedDescription)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }
}

/// A terminal action the executable can perform.
enum CommandInvocation: Equatable {
    /// Translates a piece of text into the requested destination language.
    case translate(TranslationRequest)
    /// Lists all languages the installed version of macOS can translate.
    case available

    /// Selects an action based on the command-line arguments.
    ///
    /// - Parameter arguments: Arguments after the executable name.
    /// - Throws: ``CommandError/invalidUsage`` when the arguments don't form a command.
    init(arguments: [String]) throws {
        if arguments == ["-available"] {
            self = .available
        } else {
            self = .translate(try TranslationRequest(arguments: arguments))
        }
    }
}

/// The validated input required for one translation request.
struct TranslationRequest: Equatable {
    /// Help text printed when the command receives invalid input.
    static let usage = "Usage: translate -available | translate <text> to <language> | " +
        "translate <text> -<language-code>"

    /// Text that will be translated without being sent to an external service.
    let text: String

    /// Identifier for the translation's destination language, such as `nl`.
    let targetLanguage: Locale.Language

    /// Parses either of the command's supported target-language forms.
    ///
    /// - Parameter arguments: Arguments after the executable name.
    /// - Throws: ``CommandError/invalidUsage`` when the text or destination is absent,
    ///   and ``CommandError/unknownLanguage(_:)`` when the destination cannot be resolved.
    init(arguments: [String]) throws {
        guard arguments.isEmpty == false else {
            throw CommandError.invalidUsage
        }

        if let optionIndex = arguments.lastIndex(where: { $0.hasPrefix("-") && $0.count > 1 }) {
            let option = arguments[optionIndex]
            let target = String(option.drop(while: { $0 == "-" }))
            let text = arguments[..<optionIndex].joined(separator: " ")
            guard text.isEmpty == false, optionIndex == arguments.index(before: arguments.endIndex) else {
                throw CommandError.invalidUsage
            }
            self.text = text
            self.targetLanguage = try LanguageResolver.resolve(target)
            return
        }

        guard let delimiter = arguments.lastIndex(where: { $0.caseInsensitiveCompare("to") == .orderedSame }) else {
            throw CommandError.invalidUsage
        }

        let text = arguments[..<delimiter].joined(separator: " ")
        let languageName = arguments[arguments.index(after: delimiter)...].joined(separator: " ")
        guard text.isEmpty == false, languageName.isEmpty == false else {
            throw CommandError.invalidUsage
        }
        self.text = text
        self.targetLanguage = try LanguageResolver.resolve(languageName)
    }
}

/// Translates validated requests with a downloaded Apple translation model.
@available(macOS 26.0, *)
struct Translator {
    /// Detects the source language, verifies the installed model, and translates the request.
    ///
    /// - Parameter request: The text and destination language chosen by the user.
    /// - Returns: The translated text, suitable for direct output to a shell pipeline.
    /// - Throws: ``CommandError/unrecognizedSourceLanguage`` if macOS cannot identify the
    ///   input language, or ``CommandError/languagePairNotInstalled`` if the user needs to
    ///   download the relevant Apple translation model in the Translate app.
    func translate(_ request: TranslationRequest) async throws -> String {
        guard let recognizedLanguage = NLLanguageRecognizer.dominantLanguage(for: request.text) else {
            throw CommandError.unrecognizedSourceLanguage
        }

        let sourceLanguage = Locale.Language(identifier: recognizedLanguage.rawValue)
        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLanguage, to: request.targetLanguage)
        guard status == .installed else {
            throw CommandError.languagePairNotInstalled(
                source: sourceLanguage.minimalIdentifier,
                target: request.targetLanguage.minimalIdentifier
            )
        }

        let session = TranslationSession(installedSource: sourceLanguage, target: request.targetLanguage)
        let response = try await session.translate(request.text)
        return response.targetText
    }
}

/// Produces a stable, readable list of language identifiers supported by macOS.
@available(macOS 15.0, *)
struct AvailableLanguageReporter {
    /// Returns supported translation languages, one `language-code<TAB>name` entry per line.
    ///
    /// The report describes languages that the framework supports. A supported language may
    /// still require its on-device model to be downloaded before it can be used in a translation.
    /// - Returns: A newline-separated report sorted by the language's English display name.
    func report() async -> String {
        let languages = await LanguageAvailability().supportedLanguages
        let displayLocale = Locale(identifier: "en")
        let lines = languages.map { language in
            let identifier = language.minimalIdentifier
            let name = displayLocale.localizedString(forLanguageCode: identifier) ?? identifier
            return AvailableLanguage(identifier: identifier, name: name)
        }
        .sorted(using: KeyPathComparator(\.name))
        .map { "\($0.identifier)\t\($0.name)" }

        return (["Supported translation languages (download models as needed):"] + lines)
            .joined(separator: "\n")
    }
}

/// A display-ready language record used to sort the availability report.
private struct AvailableLanguage: Comparable {
    /// BCP 47 language identifier accepted by the command.
    let identifier: String
    /// English display name used to make the report easy to scan.
    let name: String

    /// Sorts language records alphabetically by name, then identifier for deterministic output.
    static func < (lhs: AvailableLanguage, rhs: AvailableLanguage) -> Bool {
        (lhs.name, lhs.identifier) < (rhs.name, rhs.identifier)
    }
}

/// Resolves user-oriented language names and standard language identifiers.
enum LanguageResolver {
    /// Common English language names accepted after `to`.
    private static let names = [
        "arabic": "ar", "chinese": "zh", "dutch": "nl", "english": "en",
        "french": "fr", "german": "de", "hindi": "hi", "indonesian": "id",
        "italian": "it", "japanese": "ja", "korean": "ko", "polish": "pl",
        "portuguese": "pt", "russian": "ru", "spanish": "es", "thai": "th",
        "turkish": "tr", "ukrainian": "uk", "vietnamese": "vi"
    ]

    /// Converts an ISO-style code or a supported English language name into a locale language.
    ///
    /// - Parameter value: A target supplied as `nl`, `pt-BR`, or a name such as `Dutch`.
    /// - Returns: The matching Foundation language identifier.
    /// - Throws: ``CommandError/unknownLanguage(_:)`` if the target is empty or unrecognized.
    static func resolve(_ value: String) throws -> Locale.Language {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            throw CommandError.unknownLanguage(value)
        }
        let identifier = names[normalized] ?? normalized.replacingOccurrences(of: "_", with: "-")
        let language = Locale.Language(identifier: identifier)
        guard language.languageCode != nil else {
            throw CommandError.unknownLanguage(value)
        }
        return language
    }
}

/// Describes expected command failures in a form that is helpful in a terminal.
enum CommandError: LocalizedError, Equatable {
    /// The argument layout does not match either supported command form.
    case invalidUsage
    /// The requested target is neither a known name nor a valid language identifier.
    case unknownLanguage(String)
    /// macOS could not infer a source language from the supplied text.
    case unrecognizedSourceLanguage
    /// The Apple model needed by the language pair is not ready for offline translation.
    case languagePairNotInstalled(source: String, target: String)

    /// Process status returned to the calling shell.
    var exitCode: Int32 { 2 }

    /// Indicates whether the usage synopsis would help resolve the error.
    var shouldShowUsage: Bool {
        switch self {
        case .invalidUsage, .unknownLanguage:
            true
        case .unrecognizedSourceLanguage, .languagePairNotInstalled:
            false
        }
    }

    /// A concise explanation intended for standard error.
    var errorDescription: String? {
        switch self {
        case .invalidUsage:
            "expected text followed by `to <language>` or `-<language-code>`"
        case let .unknownLanguage(language):
            "unknown target language `\(language)`"
        case .unrecognizedSourceLanguage:
            "could not identify the source language"
        case let .languagePairNotInstalled(source, target):
            "Apple’s \(source) → \(target) translation model is not installed; " +
                "download it in the Translate app and try again"
        }
    }
}
