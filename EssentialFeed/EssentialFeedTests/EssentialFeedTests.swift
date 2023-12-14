import XCTest
import EssentialFeed

final class RemoteFeedLoaderTests: XCTestCase {
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "http://given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_requestsDataFromUrlTwice() {
        let url = URL(string: "http://given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load { _ in }
        sut.load { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()
        
        execute(
            sut,
            toCompleteWithResult: .failure(.connectivity),
            when: {
                let clientError = NSError(domain: "Test", code: 0)
                client.complete(with: clientError)
            }
        )
    }
    
    func test_load_deliversErrorOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        
        let samples = [199, 201, 300, 400, 500]
        
        samples.enumerated().forEach { index, code in
            execute(
                sut,
                toCompleteWithResult: .failure(.invalidData),
                when: {
                    client.complete(with: code, at: index)
                }
            )
        }
    }
    
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() {
        let (sut, client) = makeSUT()
        
        execute(
            sut,
            toCompleteWithResult: .failure(.invalidData),
            when: {
                let invalidJSON = Data("invalid.json".utf8)
                client.complete(with: 200, data: invalidJSON)
            }
        )
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()
        
        execute(
            sut,
            toCompleteWithResult: .success([]),
            when: {
                let emptyJSONList = Data("{\"items\":[]}".utf8)
                client.complete(with: 200, data: emptyJSONList)
            }
        )
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithNotEmptyJSONList() {
        let (sut, client) = makeSUT()
        
        let feedItem1 = FeedItem(
            id: UUID(),
            imageURL: URL(string: "http://url.com")!
        )
        
        let feedItem1JSON = [
            "id": feedItem1.id.uuidString,
            "image": feedItem1.imageURL.absoluteString,
        ]
        
        let feedItem2 = FeedItem(
            id: UUID(),
            description: "a description",
            location: "a location",
            imageURL: URL(string: "http://url.com")!
        )
        
        let feedItem2JSON = [
            "id": feedItem2.id.uuidString,
            "description": feedItem2.description,
            "location": feedItem2.location,
            "image": feedItem2.imageURL.absoluteString,
        ]
        
        let feedItemsJSON = [
            "items": [feedItem1JSON, feedItem2JSON]
        ]
        
        execute(
            sut,
            toCompleteWithResult: .success([feedItem1, feedItem2]),
            when: {
                let data = try! JSONSerialization.data(withJSONObject: feedItemsJSON)
                client.complete(with: 200, data: data)
            }
        )
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        url: URL = URL(string: "http://url.com")!
    ) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url , client: client)
        return (sut, client)
    }
    
    private func execute(
        _ sut: RemoteFeedLoader,
        toCompleteWithResult result: RemoteFeedLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var capturedResults = [RemoteFeedLoader.Result]()
        sut.load { capturedResults.append($0) }
        
        action()
        
        XCTAssertEqual(capturedResults, [result], file: file, line: line)
    }
    
    private class HTTPClientSpy: HTTPClient {
        private var messages = [
            (
                url: URL,
                completion: (HTTPClientResult) -> Void
            )
        ]()
        
        var requestedURLs: [URL] {
            return messages.map({ $0.url })
        }
        
        func get(
            from url: URL,
            _ completion: @escaping (HTTPClientResult) -> Void
        ) {
            messages.append((url, completion))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(
            with statusCode: Int,
            data: Data = Data(),
            at index: Int = 0
        ) {
            let response = HTTPURLResponse(
                url: messages[index].url,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            messages[index].completion(.success(data, response))
        }
    }
}
