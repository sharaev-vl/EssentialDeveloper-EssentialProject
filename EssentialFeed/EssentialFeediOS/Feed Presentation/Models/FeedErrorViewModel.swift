struct FeedErrorViewModel {
    static var noError: Self {
        return Self(message: nil)
    }

    let message: String?
    
    static func error(message: String) -> Self {
        return Self(message: message)
    }
}
