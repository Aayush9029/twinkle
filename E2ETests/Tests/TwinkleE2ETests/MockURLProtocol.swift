import Foundation

/// URLProtocol subclass that intercepts network requests for testing
final class MockURLProtocol: URLProtocol {
    /// Handler to process requests and return mock responses
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Registered fixtures: URL path -> (statusCode, data)
    static var fixtures: [String: (Int, Data)] = [:]

    /// Simulated delay for responses
    static var responseDelay: Duration = .zero

    /// Whether to simulate rate limiting
    static var simulateRateLimit = false

    /// Whether to simulate timeout
    static var simulateTimeout = false

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client = client else { return }

        // Simulate timeout
        if Self.simulateTimeout {
            client.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }

        // Simulate rate limiting
        if Self.simulateRateLimit {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "60"]
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocolDidFinishLoading(self)
            return
        }

        // Use custom handler if provided
        if let handler = Self.requestHandler {
            do {
                let (response, data) = try handler(request)

                // Apply delay
                if Self.responseDelay > .zero {
                    Thread.sleep(forTimeInterval: Self.responseDelay.timeInterval)
                }

                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: data)
                client.urlProtocolDidFinishLoading(self)
            } catch {
                client.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        // Check fixtures by path
        if let url = request.url,
           let (statusCode, data) = Self.fixtures[url.path] {
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            if Self.responseDelay > .zero {
                Thread.sleep(forTimeInterval: Self.responseDelay.timeInterval)
            }

            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
            return
        }

        // No handler or fixture - fail with not found
        client.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
    }

    override func stopLoading() {
        // Nothing to clean up
    }

    // MARK: - Helpers

    static func reset() {
        requestHandler = nil
        fixtures = [:]
        responseDelay = .zero
        simulateRateLimit = false
        simulateTimeout = false
    }

    /// Register to intercept URLSession requests
    static func register() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    /// Unregister from intercepting
    static func unregister() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
