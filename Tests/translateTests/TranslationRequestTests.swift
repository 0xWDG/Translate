//
//  TranslationRequestTests.swift
//  Translate
//
//  Created by Wesley de Groot on 2026-10-01.
//  https://wesleydegroot.nl
//
//  https://github.com/0xWDG/Translate
//  MIT License
//
import Foundation
import Testing
@testable import translate

@Test("Parses a natural-language destination")
func parsesNamedDestination() throws {
    let request = try TranslationRequest(arguments: ["my string", "to", "Dutch"])

    #expect(request.text == "my string")
    #expect(request.targetLanguage.minimalIdentifier == "nl")
}

@Test("Parses a compact language option")
func parsesLanguageOption() throws {
    let command = try CommandInvocation(arguments: ["my string", "-nl"])
    guard case let .translate(request) = command else {
        Issue.record("Expected the translation command")
        return
    }

    #expect(request.text == "my string")
    #expect(request.targetLanguage.minimalIdentifier == "nl")
}

@Test("Parses the available-languages command")
func parsesAvailableLanguagesCommand() throws {
    let command = try CommandInvocation(arguments: ["-available"])

    #expect(command == .available)
}

@Test("Rejects an incomplete request")
func rejectsIncompleteRequest() {
    #expect(throws: CommandError.invalidUsage) {
        try TranslationRequest(arguments: ["my string"])
    }
}
