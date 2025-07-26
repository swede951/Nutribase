import Foundation

class NetworkService {
    // Singleton instance
    static let shared = NetworkService()
    
    // Maximum number of retries for a request
    private let maxRetries = 3
    
    // Exponential backoff delay in seconds
    private func backoffDelay(for attempt: Int) -> TimeInterval {
        return pow(2.0, Double(attempt)) * 0.5 // 0.5s, 1s, 2s
    }
    
    // Perform a request with automatic retry
    func performRequest(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        performRequestWithRetry(request, currentAttempt: 0, completion: completion)
    }
    
    // Internal method to handle retries
    private func performRequestWithRetry(_ request: URLRequest, currentAttempt: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var modifiedRequest = request
        
        // Increase timeout for each retry attempt
        modifiedRequest.timeoutInterval = 15.0 + Double(currentAttempt) * 5.0
        
        // Log the attempt
        print("🌐 Network request attempt \(currentAttempt + 1) of \(maxRetries + 1) to \(request.url?.absoluteString ?? "unknown URL")")
        
        URLSession.shared.dataTask(with: modifiedRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Check for network errors that warrant a retry
            if let error = error as NSError? {
                let shouldRetry = self.shouldRetryRequest(error: error, attempt: currentAttempt)
                
                if shouldRetry {
                    let delay = self.backoffDelay(for: currentAttempt)
                    print("🔄 Retrying request after \(delay) seconds due to error: \(error.localizedDescription)")
                    
                    // Retry after delay with exponential backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequestWithRetry(request, currentAttempt: currentAttempt + 1, completion: completion)
                    }
                    return
                }
            }
            
            // If we got here, either the request succeeded or we've exhausted retries
            completion(data, response, error)
        }.resume()
    }
    
    // Determine if a request should be retried based on the error
    private func shouldRetryRequest(error: NSError, attempt: Int) -> Bool {
        // Don't retry if we've reached the maximum number of attempts
        if attempt >= maxRetries {
            return false
        }
        
        // Retry on network connection errors
        let networkErrorCodes = [
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDNSLookupFailed,
            NSURLErrorCannotFindHost
        ]
        
        return networkErrorCodes.contains(error.code)
    }
}
