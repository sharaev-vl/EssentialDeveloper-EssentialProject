public protocol FeedErrorView {
    func display(_ viewModel: FeedErrorViewModel)
}

public struct FeedErrorViewModel {
    static var noError: Self {
        return Self(message: nil)
    }

    public let message: String?
    
    static func error(message: String) -> Self {
        return Self(message: message)
    }
}
