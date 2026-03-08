//
//  main.swift
//  AsyncTutorial
//
//  Created by 高松由樹 on 2026/03/08.
//

import Foundation

//await runSimgleFetch()
//await runParallelFetch()
//await cancellableTask()
let result = try await fetchTotalBytes(urls: ["https://httpbin.org/delay/1", "https://httpbin.org/delay/1"])
print("取得結果: \(result)")


func runSimgleFetch() async {
    let urlString = "https://httpbin.org/get"
    let task = Task {
        try await Fetcher.fetchData(from: urlString)
    }
    do {
        let data = try await task.value
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("キー数: \(json.keys.count)")
        }
        print("単一取得: \(data.count) バイト")
    } catch {
        print("単一取得エラー: \(error)")
    }
}

func runParallelFetch() async {
    async let a = Fetcher.fetchData(from: "https://httpbin.org/delay/1")
    async let b = Fetcher.fetchData(from: "https://httpbin.org/delay/1")
    do {
        let (dataA, dataB) = try await (a, b)
        print("並列取得: A=\(dataA.count), B=\(dataB.count) バイト")
    } catch {
        print("並列取得エラー: \(error)")
    }
    
}

func cancellableTask() async {
    let task = Task {
        try await Fetcher.fetchData(from: "https://httpbin.org/delay/5")
    }
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        task.cancel()
    }
    do {
        let data = try await task.value
        print("取得成功")
    } catch is CancellationError {
        print("キャンセルされました")
    } catch FetcherError.networkError(let underlyingError) {
        let nsError = underlyingError as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
            print("キャンセルされました")
        } else {
            print("エラーが発生: \(underlyingError)")
        }
    } catch let error as URLError where error.code == .cancelled {
        print("キャンセルされました（URLSession）")
    } catch {
        print("エラーが発生: \(error)")
    }
}

func fetchTotalBytes(urls: [String]) async throws -> Int {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for urlString in urls {
            group.addTask {
                try await Fetcher.fetchData(from: urlString)
            }
        }
        var total = 0
        for try await data in group {
            total += data.count
        }
        return total
    }
}
