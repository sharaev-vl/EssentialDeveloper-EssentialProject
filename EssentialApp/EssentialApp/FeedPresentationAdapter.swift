import Combine
import EssentialFeed
import EssentialFeediOS

public final class FeedPresentationAdapter: FeedViewControllerDelegate {
    private let feedLoader: () -> AnyPublisher<[FeedImage], Error>
    private var cancellable: Cancellable?
    var presenter: FeedPresenter?
    
    init(feedLoader: @escaping () -> AnyPublisher<[FeedImage], Error>) {
        self.feedLoader = feedLoader
    }
    
    public func didRequestFeedRefresh() {
        presenter?.didStartLoadingFeed()
        
        cancellable = feedLoader()
            .dispatchOnMainQueue()
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                        
                    case .failure(let error):
                        self?.presenter?.didFinishLoadingFeed(with: error)
                    }
                },
                receiveValue: { [weak self] feed in
                    self?.presenter?.didFinishLoadingFeed(with: feed)
                }
            )
    }
}
