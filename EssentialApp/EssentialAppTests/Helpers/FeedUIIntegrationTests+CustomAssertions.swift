import EssentialFeed
import EssentialFeediOS
import XCTest

extension FeedUIIntegrationTests {
    func assertThat(
        _ sut: ListViewController,
        isRendering feed: [FeedImage],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        sut.view.enforceLayoutCycle()
        
        guard sut.numberOfRenderedFeedImageViews == feed.count else {
            return XCTFail(
                "Expected \(feed.count) images, got \(sut.numberOfRenderedFeedImageViews) instead",
                file: file,
                line: line
            )
        }
        
        feed.enumerated().forEach { index, image in
            assertThat(
                sut,
                hasViewConfiguredFor: image,
                at: index,
                file: file,
                line: line
            )
        }
        
        executeRunLoopToCleanUpReferences()
    }
    
    func assertThat(
        _ sut: ListViewController,
        hasViewConfiguredFor image: FeedImage,
        at index: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let view = sut.feedImageView(at: index)
        guard let cell = view as? FeedImageCell else {
            return XCTFail(
                "Expected \(FeedImageCell.self) instance, got \(String(describing: view)) instead",
                file: file,
                line: line
            )
        }
        
        let shouldLocationBeVisible = image.location != nil
        XCTAssertEqual(
            cell.isShowingLocation,
            shouldLocationBeVisible,
            "Expected `isShowingLocation` to be \(shouldLocationBeVisible) at index \(index)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            cell.descriptionText,
            image.description,
            "Expected `descriptionText` to be \(String(describing: image.description)) at index \(index)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            cell.locationText,
            image.location,
            "Expected `locationText` to be \(String(describing: image.location)) at index \(index)",
            file: file,
            line: line
        )
    }
}
