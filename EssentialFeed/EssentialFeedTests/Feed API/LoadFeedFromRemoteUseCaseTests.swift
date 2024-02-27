import EssentialFeed
import XCTest

// swiftlint:disable force_unwrapping
// swiftlint:disable force_try

final class LoadFeedFromRemoteUseCaseTests: XCTestCase {
    func test_load_deliversErrorOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        
        let samples = [199, 201, 300, 400, 500]
        
        samples.enumerated().forEach { index, code in
            execute(
                sut,
                toCompleteWithResult: failure(.invalidData),
                when: {
                    let json = makeItemsJSON([])
                    client.complete(withStatusCode: code, data: json, at: index)
                }
            )
        }
    }
    
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() {
        let (sut, client) = makeSUT()
        
        execute(
            sut,
            toCompleteWithResult: failure(.invalidData),
            when: {
                let invalidJSON = Data("invalid.json".utf8)
                client.complete(withStatusCode: 200, data: invalidJSON)
            }
        )
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()
        
        execute(
            sut,
            toCompleteWithResult: .success([]),
            when: {
                let emptyJSONList = makeItemsJSON([])
                client.complete(withStatusCode: 200, data: emptyJSONList)
            }
        )
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithNotEmptyJSONList() {
        let (sut, client) = makeSUT()
        
        let item1 = makeItem(
            id: UUID(),
            imageURL: URL(string: "http://url.com")!
        )
        
        let item2 = makeItem(
            id: UUID(),
            imageURL: URL(string: "http://url.com")!,
            description: "a description",
            location: "a location"
        )
        
        let items = [item1.model, item2.model]
        
        execute(
            sut,
            toCompleteWithResult: .success(items),
            when: {
                let json = makeItemsJSON([item1.json, item2.json])
                client.complete(withStatusCode: 200, data: json)
            }
        )
    }
}

// MARK: - Helpers

extension LoadFeedFromRemoteUseCaseTests {
    private func makeSUT(
        url: URL = URL(string: "http://url.com")!,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        
        return (sut, client)
    }
    
    private func failure(
        _ error: RemoteFeedLoader.Error
    ) -> RemoteFeedLoader.Result {
        return .failure(error)
    }
    
    private func makeItem(
        id: UUID,
        imageURL: URL,
        description: String? = nil,
        location: String? = nil
    ) -> (model: FeedImage, json: [String: Any]) {
        let model = FeedImage(
            id: id,
            url: imageURL,
            description: description,
            location: location
        )
        
        let json = [
            "id": model.id.uuidString,
            "description": model.description,
            "location": model.location,
            "image": model.url.absoluteString
        ].compactMapValues { $0 }
        
        return (model, json)
    }
    
    private func makeItemsJSON(_ items: [[String: Any]]) -> Data {
        let json = ["items": items]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func execute(
        _ sut: RemoteFeedLoader,
        toCompleteWithResult expectedResult: RemoteFeedLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for load completion")
        
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedItems), .success(expectedItems)):
                XCTAssertEqual(
                    receivedItems,
                    expectedItems,
                    file: file,
                    line: line
                )
                
            case let (
                .failure(receivedError as RemoteFeedLoader.Error),
                .failure(expectedError as RemoteFeedLoader.Error)
            ):
                XCTAssertEqual(
                    receivedError,
                    expectedError,
                    file: file,
                    line: line
                )
                
            default:
                XCTFail(
                    "Expected result \(expectedResult) and got \(receivedResult) instead.",
                    file: file,
                    line: line
                )
            }
            
            exp.fulfill()
        }
        
        action()
        
        wait(for: [exp], timeout: 1.0)
    }
}

// swiftlint:enable force_unwrapping
// swiftlint:enable force_try
