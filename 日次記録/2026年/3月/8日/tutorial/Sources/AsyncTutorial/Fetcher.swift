//
//  Fetcher.swift
//  AsyncTutorial
//
//  Created by 高松由樹 on 2026/03/08.
//

import Foundation

enum FetcherError: Error {
    case invaliURL
    case networkError(Error)
}

enum Fetcher {
    static func fetchData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw FetcherError.invaliURL
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            throw FetcherError.networkError(error)
        }
    }
}
