//
//  AsyncTutorialTests.swift
//  AsyncTutorial
//
//  Created by 高松由樹 on 2026/03/08.
//

import Testing
@testable import AsyncTutorial

@Suite("Fetcherのテスト")
struct FetcherTests {
    @Test("無効なURLでinvalidURLがthrowされる")
    func fetchInvalidURL() async throws {
        await #expect(throws: FetcherError.self) {
            try await Fetcher.fetchData(from: "not-a-valid-url")
        }
    }
}
