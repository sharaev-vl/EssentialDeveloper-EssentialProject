import EssentialFeed
import EssentialFeediOS
import UIKit
import XCTest

// swiftlint:disable force_unwrapping
// swiftlint:disable line_length
// swiftlint:disable file_length

private final class FakeRefreshControl: UIRefreshControl {
    private var _isRefreshing = false
    
    override var isRefreshing: Bool { _isRefreshing }
    
    override func beginRefreshing() {
        _isRefreshing = true
    }
    
    override func endRefreshing() {
        _isRefreshing = false
    }
}

final class FeedViewControllerTests: XCTestCase {
    func test_loadFeedActions_requestsFeedFromLoader() {
        let (sut, loader) = makeSUT()
        XCTAssertTrue(loader.feedRequests.isEmpty)
        
        sut.loadViewIfNeeded()
        XCTAssertEqual(
            loader.feedRequests.count,
            0,
            "Expected no loading requests before view is loaded"
        )
        
        sut.simulateAppearance()
        XCTAssertEqual(
            loader.feedRequests.count,
            1,
            "Expected a loading requests once view is loaded"
        )
        
        sut.simulateUserInitiatedFeedReload()
        XCTAssertEqual(
            loader.feedRequests.count,
            2,
            "Expected another loading request once the the user initiates a load"
        )
        
        sut.simulateUserInitiatedFeedReload()
        XCTAssertEqual(
            loader.feedRequests.count,
            3,
            "Expected another loading request once the the user initiates another load"
        )
    }
    
    func test_loadingFeedIndicator_isVisibleWhileLoadingFeed() {
        let (sut, loader) = makeSUT()
        
        sut.simulateAppearance()
        XCTAssertTrue(
            sut.isShowingReloadingIndicator,
            "Expected the loading indicator once the view is loaded"
        )
        
        loader.completeFeedLoading(at: 0)
        XCTAssertFalse(
            sut.isShowingReloadingIndicator,
            "Expected no loading indicator once the the loading is completed successfully"
        )
        
        sut.simulateUserInitiatedFeedReload()
        XCTAssertTrue(
            sut.isShowingReloadingIndicator,
            "Expected the loading indicator once the user initiates a reload"
        )
        
        loader.completeFeedLoadingWithError(at: 1)
        XCTAssertFalse(
            sut.isShowingReloadingIndicator,
            "Expected no loading indicator once the the loading is completed with error"
        )
        
        sut.simulateAppearance()
        XCTAssertFalse(
            sut.isShowingReloadingIndicator,
            "Expected no loading indicator after the view is loaded once"
        )
    }
    
    func test_loadFeedCompletion_rendersSuccessfullyLoadedFeed() {
        let (sut, loader) = makeSUT()
        let image0 = makeImage(
            description: "a description",
            location: "a location"
        )
        let image1 = makeImage(
            location: "a location"
        )
        let image2 = makeImage(
            description: "a description"
        )
        let image3 = makeImage()
        
        sut.simulateAppearance()
        assertThat(sut, isRendering: [])
        
        loader.completeFeedLoading(with: [image0])
        assertThat(sut, isRendering: [image0])
        
        sut.simulateUserInitiatedFeedReload()
        loader.completeFeedLoading(with: [image0, image1, image2, image3])
        assertThat(sut, isRendering: [image0, image1, image2, image3])
    }
    
    func test_loadFeedCompletion_doesNotAlterCurrentRenderingStateOnError() {
        let (sut, loader) = makeSUT()
        let image0 = makeImage(
            description: "a description",
            location: "a location"
        )
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [image0])
        assertThat(sut, isRendering: [image0])
        
        sut.simulateUserInitiatedFeedReload()
        loader.completeFeedLoadingWithError(at: 1)
        assertThat(sut, isRendering: [image0])
    }
    
    func test_feedImageView_loadsImageURLWhenVisible() {
        let (sut, loader) = makeSUT()
        let image0 = makeImage()
        let image1 = makeImage()
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [image0, image1])
        
        XCTAssertEqual(
            loader.loadedImageURLs,
            [],
            "Expected no image URL requests until views become visible"
        )
        
        sut.simulateFeedImageViewVisible(at: 0)
        XCTAssertEqual(
            loader.loadedImageURLs,
            [image0.url],
            "Expected first image URL request once first view becomes visible"
        )
        
        sut.simulateFeedImageViewVisible(at: 1)
        XCTAssertEqual(
            loader.loadedImageURLs,
            [image0.url, image1.url],
            "Expected second image URL request once second view becomes visible"
        )
    }
    
    func test_feedImageView_cancelsImageLoadingWhenNotVisibleAnymore() {
        let (sut, loader) = makeSUT()
        let image0 = makeImage()
        let image1 = makeImage()
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [image0, image1])
        
        XCTAssertEqual(
            loader.cancelledImageURLs,
            [],
            "Expected no cancelled image URLs until image gets invisible"
        )
        
        sut.simulateFeedImageViewNotVisible(at: 0)
        XCTAssertEqual(
            loader.cancelledImageURLs,
            [image0.url],
            "Expected one cancelled image URL request once the first image isn't visible"
        )
        
        sut.simulateFeedImageViewNotVisible(at: 1)
        XCTAssertEqual(
            loader.cancelledImageURLs,
            [image0.url, image1.url],
            "Expected two cancelled image URL requests once the second image is also not visible"
        )
    }
    
    func test_feedImageViewLoadingIndicator_isVisibleWhileLoadingImage() {
        let (sut, loader) = makeSUT()
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [makeImage(), makeImage()])
        
        let view0 = sut.simulateFeedImageViewVisible(at: 0)
        let view1 = sut.simulateFeedImageViewVisible(at: 1)
        XCTAssertEqual(
            view0?.isShowingImageLoadingIndicator,
            true,
            "Expected loading indicator for the first view while loading the the first image"
        )
        XCTAssertEqual(
            view1?.isShowingImageLoadingIndicator,
            true,
            "Expected loading indicator for the second view while loading the the second image"
        )
        
        loader.completeImageLoading(at: 0)
        XCTAssertEqual(
            view0?.isShowingImageLoadingIndicator,
            false,
            "Expected no loading indicator for the first view while it's loaded successfully"
        )
        XCTAssertEqual(
            view1?.isShowingImageLoadingIndicator,
            true,
            "Expected loading indicator for the second view since the loading isn't finished yet"
        )
        
        loader.completeImageLoadingWithError(at: 1)
        XCTAssertEqual(
            view0?.isShowingImageLoadingIndicator,
            false,
            "Expected no loading indicator state change for the first view once the second image loading completes with error"
        )
        XCTAssertEqual(
            view1?.isShowingImageLoadingIndicator,
            false,
            "Expected no loading indicator for the second view once the second image loading completes with  error"
        )
    }
    
    func test_feedImageView_rendersImageLoadedFromURL() {
        let (sut, loader) = makeSUT()
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [makeImage(), makeImage()])
        
        let view0 = sut.simulateFeedImageViewVisible(at: 0)
        let view1 = sut.simulateFeedImageViewVisible(at: 1)
        XCTAssertEqual(
            view0?.renderedImage,
            nil,
            "Expected no image for the first view while loading the first image"
        )
        XCTAssertEqual(
            view1?.renderedImage,
            nil,
            "Expected no image for the second view while loading the second image"
        )
        
        let imageData0 = UIImage.make(withColor: .red).pngData()!
        loader.completeImageLoading(with: imageData0, at: 0)
        XCTAssertEqual(
            view0?.renderedImage,
            imageData0,
            "Expected an image for the first view while the first image loading is completed successfully"
        )
        XCTAssertEqual(
            view1?.renderedImage,
            nil,
            "Expected no image for the second view on the first image loading is completed successfully"
        )
        
        let imageData1 = UIImage.make(withColor: .blue).pngData()!
        loader.completeImageLoading(with: imageData1, at: 1)
        XCTAssertEqual(
            view0?.renderedImage,
            imageData0,
            "Expected no image state change for the first view on the second image loading is completed successfully"
        )
        XCTAssertEqual(
            view1?.renderedImage,
            imageData1,
            "Expected an image for the second view while the second image loading is completed successfully"
        )
    }
    
    func test_feedImageViewRetryButton_isVisibleOnImageURLLoadError() {
        let (sut, loader) = makeSUT()
        
        sut.simulateAppearance()
        loader.completeFeedLoading(with: [makeImage(), makeImage()])
        
        let view0 = sut.simulateFeedImageViewVisible(at: 0)
        let view1 = sut.simulateFeedImageViewVisible(at: 1)
        XCTAssertEqual(
            view0?.isShowingRetryAction,
            false,
            "Expected no retry action for the first view while loading the first image"
        )
        XCTAssertEqual(
            view1?.isShowingRetryAction,
            false,
            "Expected no retry action for the second view while loading the second image"
        )
        
        let imageData0 = UIImage.make(withColor: .red).pngData()!
        loader.completeImageLoading(with: imageData0, at: 0)
        XCTAssertEqual(
            view0?.isShowingRetryAction,
            false,
            "Expected no retry action for the first view on the first image loading is completed successfully"
        )
        XCTAssertEqual(
            view1?.isShowingRetryAction,
            false,
            "Expected no retry action for the second view on the first image loading is completed successfully"
        )
        
        loader.completeFeedLoadingWithError(at: 1)
        XCTAssertEqual(
            view0?.isShowingRetryAction,
            false,
            "Expected no retry action state change for the first view on the second image loading is completed with an error"
        )
        XCTAssertEqual(
            view1?.isShowingRetryAction,
            true,
            "Expected a retry action for the second view while the second image loading is completed with an error"
        )
    }
}

// MARK: - Helpers

private extension FeedViewControllerTests {
    func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: FeedViewController,
        loader: LoaderSpy
    ) {
        let loader = LoaderSpy()
        let sut = FeedViewController(
            feedLoader: loader,
            imageLoader: loader
        )
        trackForMemoryLeaks(loader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, loader)
    }
    
    func makeImage(
        url: URL = anyURL(),
        description: String? = nil,
        location: String? = nil
    ) -> FeedImage {
        return FeedImage(
            id: UUID(),
            url: anyURL(),
            description: description,
            location: location
        )
    }
    
    func assertThat(
        _ sut: FeedViewController,
        isRendering feed: [FeedImage],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
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
    }
    
    func assertThat(
        _ sut: FeedViewController,
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

private extension FeedViewControllerTests {
    class LoaderSpy {
        private var _feedRequests = [(FeedLoader.Result) -> Void]()
        private var _cancelledImageURLs = [URL]()
        private var _imageRequests = [(url: URL, completion: (FeedImageDataLoader.Result) -> Void)]()
    }
}

private extension FeedViewControllerTests.LoaderSpy {
    struct TaskSpy: FeedImageDataLoaderTask {
        let cancelCallBack: () -> Void
        
        func cancel() {
            cancelCallBack()
        }
    }
}

extension FeedViewControllerTests.LoaderSpy: FeedLoader {
    var feedRequests: [(FeedLoader.Result) -> Void] {
        return _feedRequests
    }
    
    func load(completion: @escaping (FeedLoader.Result) -> Void) {
        _feedRequests.append(completion)
    }
    
    func completeFeedLoading(
        with feed: [FeedImage] = [],
        at index: Int = 0
    ) {
        feedRequests[index](.success(feed))
    }
    
    func completeFeedLoadingWithError(at index: Int = 0) {
        feedRequests[index](.failure(anyNSError()))
    }
}

extension FeedViewControllerTests.LoaderSpy: FeedImageDataLoader {
    var imageRequests: [(url: URL, completion: (FeedImageDataLoader.Result) -> Void)] {
        return _imageRequests
    }
    
    var loadedImageURLs: [URL] {
        return imageRequests.map { $0.url }
    }
    
    var cancelledImageURLs: [URL] {
        return _cancelledImageURLs
    }
    
    func loadImageData(
        from url: URL,
        completion: @escaping (FeedImageDataLoader.Result) -> Void
    ) -> FeedImageDataLoaderTask {
        _imageRequests.append((url, completion))
        return TaskSpy { [weak self] in
            self?.cancelImageDataLoading(from: url)
        }
    }
    
    func cancelImageDataLoading(from url: URL) {
        _cancelledImageURLs.append(url)
    }
    
    func completeImageLoading(
        with imageData: Data = Data(),
        at index: Int = 0
    ) {
        imageRequests[index].completion(.success(imageData))
    }
    
    func completeImageLoadingWithError(at index: Int) {
        imageRequests[index].completion(.failure(anyNSError()))
    }
}

private extension UITableViewController {
    func simulateAppearance() {
        if !isViewLoaded {
            loadViewIfNeeded()
            replaceRefreshControlWithFakeForiOS17Support()
        }
        
        beginAppearanceTransition(true, animated: false)
        endAppearanceTransition()
    }
    
    private func replaceRefreshControlWithFakeForiOS17Support() {
        let fake = FakeRefreshControl()
        
        refreshControl?.allTargets.forEach { [weak self] target in
            self?.refreshControl?.actions(
                forTarget: target,
                forControlEvent: .valueChanged
            )?
                .forEach { action in
                    fake.addTarget(
                        target,
                        action: Selector(action),
                        for: .valueChanged
                    )
                }
        }
        
        refreshControl = fake
    }
}

private extension UIRefreshControl {
    func simulatePullToRefresh() {
        allTargets.forEach { [weak self] target in
            self?.actions(
                forTarget: target,
                forControlEvent: .valueChanged
            )?
                .forEach { action in
                    (target as NSObject).perform(Selector(action))
                }
        }
    }
}

private extension FeedViewController {
    var isShowingReloadingIndicator: Bool {
        return refreshControl?.isRefreshing == true
    }
    
    var numberOfRenderedFeedImageViews: Int {
        return tableView.numberOfRows(inSection: feedImagesSection)
    }
    
    private var feedImagesSection: Int {
        return 0
    }
    
    func simulateUserInitiatedFeedReload() {
        refreshControl?.simulatePullToRefresh()
    }
    
    @discardableResult
    func simulateFeedImageViewVisible(at index: Int) -> FeedImageCell? {
        return feedImageView(at: index) as? FeedImageCell
    }
    
    func simulateFeedImageViewNotVisible(at row: Int) {
        let view = simulateFeedImageViewVisible(at: row)
        let delegate = tableView.delegate
        let index = IndexPath(row: row, section: 0)
        
        delegate?.tableView?(
            tableView,
            didEndDisplaying: view!,
            forRowAt: index
        )
    }
    
    func feedImageView(at row: Int) -> UITableViewCell? {
        let ds = tableView.dataSource
        let index = IndexPath(row: row, section: feedImagesSection)
        return ds?.tableView(tableView, cellForRowAt: index)
    }
}

private extension FeedImageCell {
    var isShowingLocation: Bool {
        return !locationContainer.isHidden
    }
    
    var isShowingImageLoadingIndicator: Bool {
        return feedImageContainer.isShimmering
    }
    
    var descriptionText: String? {
        return descriptionLabel.text
    }
    
    var locationText: String? {
        return locationLabel.text
    }
    
    var renderedImage: Data? {
        return feedImageView.image?.pngData()
    }
    
    var isShowingRetryAction: Bool {
        return !feedImageRetryButton.isHidden
    }
}

private extension UIImage {
    static func make(withColor color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: rect.size, format: format).image { rendererContext in
            color.setFill()
            rendererContext.fill(rect)
        }
    }
}

// swiftlint:enable force_unwrapping
// swiftlint:enable line_length
// swiftlint:enable file_length
