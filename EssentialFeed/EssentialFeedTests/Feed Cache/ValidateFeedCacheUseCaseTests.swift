import EssentialFeed
import XCTest

final class ValidateFeedCacheUseCaseTests: XCTestCase {
    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()
        
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_validateCache_deletesCacheOnRetrievalError() {
        let (sut, store) = makeSUT()
        
        sut.validateCache { _ in }
        store.completeRetrieval(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
    }
    
    func test_validateCache_doesNotDeleteCacheOnEmptyCache() {
        let (sut, store) = makeSUT()
        
        sut.validateCache { _ in }
        store.completeRetrievalWithEmptyCache()
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_validateCache_doesNotDeleteNonExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        let nonExpiredTimestamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: 1)
        
        sut.validateCache { _ in }
        store.completeRetrieval(
            with: feed.local,
            timestamp: nonExpiredTimestamp
        )
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_validateCache_deletesCacheOnExpiration() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        let expirationTimestamp = fixedCurrentDate.minusFeedCacheMaxAge()
        
        sut.validateCache { _ in }
        store.completeRetrieval(
            with: feed.local,
            timestamp: expirationTimestamp
        )
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
    }
    
    func test_validateCache_deletesExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        let expiredTimestamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: -1)
        
        sut.validateCache { _ in }
        store.completeRetrieval(
            with: feed.local,
            timestamp: expiredTimestamp
        )
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
    }
    
    func test_validateCache_doesNotDeleteInvalidCacheAfterSUTHasBeenDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)
        
        sut?.validateCache { _ in }
        
        sut = nil
        store.completeRetrieval(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_validateCache_failsOnDeletionErrorOfFailedRetrieval() {
        let (sut, store) = makeSUT()
        let deletionError = anyNSError()
        
        expect(sut, toCompleteWith: .failure(deletionError)) {
            store.completeRetrieval(with: anyNSError())
            store.completeDeletion(with: deletionError)
        }
    }
    
    func test_validateCache_succeedsOnSuccessfulDeletionOfFailedRetrieval() {
        let (sut, store) = makeSUT()
        
        expect(sut, toCompleteWith: .success(Void())) {
            store.completeRetrieval(with: anyNSError())
            store.completeDeletionSuccessfully()
        }
    }
    
    func test_validateCache_succeedsOnEmptyCache() {
        let (sut, store) = makeSUT()
        
        expect(sut, toCompleteWith: .success(Void())) {
            store.completeRetrievalWithEmptyCache()
        }
    }
    
    func test_validateCache_succeedsOnNonExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let nonExpiredTimestamp = fixedCurrentDate
            .minusFeedCacheMaxAge()
            .adding(seconds: 1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        
        expect(sut, toCompleteWith: .success(Void())) {
            store.completeRetrieval(with: feed.local, timestamp: nonExpiredTimestamp)
        }
    }
    
    func test_validateCache_failsOnDeletionErrorOfExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let expiredTimestamp = fixedCurrentDate
            .minusFeedCacheMaxAge()
            .adding(seconds: -1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        let deletionError = anyNSError()
        
        expect(sut, toCompleteWith: .failure(deletionError)) {
            store.completeRetrieval(with: feed.local, timestamp: expiredTimestamp)
            store.completeDeletion(with: deletionError)
        }
    }
    
    func test_validateCache_succeedsOnSuccessfulDeletionOfExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let expiredTimestamp = fixedCurrentDate
            .minusFeedCacheMaxAge()
            .adding(seconds: -1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })
        
        expect(sut, toCompleteWith: .success(Void())) {
            store.completeRetrieval(with: feed.local, timestamp: expiredTimestamp)
            store.completeDeletionSuccessfully()
        }
    }
}

// MARK: - Helpers

private extension ValidateFeedCacheUseCaseTests {
    func makeSUT(
        currentDate: @escaping () -> Date = Date.init,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        
        return (sut, store)
    }
    
    func expect(
        _ sut: LocalFeedLoader,
        toCompleteWithResult expectedResult: LocalFeedLoader.LoadResult,
        on action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for load completion")
        
        sut.load { [weak self] receivedResult in
            switch (receivedResult, expectedResult) {
            case (.success(let receivedImages), .success(let expectedImages)):
                XCTAssertEqual(
                    receivedImages,
                    expectedImages,
                    file: file,
                    line: line
                )
                
            case (.failure(let receivedError), .failure(let expectedError)):
                self?.compare(
                    error: receivedError as NSError,
                    with: expectedError as NSError,
                    file: file,
                    line: line
                )
                
            default:
                XCTFail(
                    "Expected \(expectedResult), got \(receivedResult)",
                    file: file,
                    line: line
                )
            }
            
            exp.fulfill()
        }
        
        action()
        wait(for: [exp], timeout: 1.0)
    }
    
    func expect(
        _ sut: LocalFeedLoader,
        toCompleteWith expectedResult: LocalFeedLoader.ValidationResult,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Wait for completion")
        sut.validateCache { receivedResult in
            switch (receivedResult, expectedResult) {
            case (.success, .success):
                break
                
            case let (.failure(receivedError), .failure(expectedError)):
                XCTAssertEqual(
                    receivedError as NSError,
                    expectedError as NSError,
                    file: file,
                    line: line
                )
                
            default:
                XCTFail(
                    "Expected result \(expectedResult), got \(receivedResult) instead",
                    file: file,
                    line: line
                )
            }
            
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1)
    }
}
