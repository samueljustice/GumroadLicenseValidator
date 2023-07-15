//
//  GumroadClient.swift
//  GumroadLicenseCheck
//
//  Created by Daniel Kasaj on 07.01.2022..
//

import Foundation

/// Simple class to send requests to Gumroad's Verify License API endpoint, which does not require an OAuth application.
///
/// Class initializer is failable to ensure that the class has a product id.
///
/// - note: Has a configurable property `disputedPurchaseInvalidatesLicense`
public final class GumroadClient {
    let productId: String

    /// Initializes only if product id string is not empty
    ///
    /// Update for Gumroad 2023 - "Important: Our license key verification API requires the product_id parameter instead of product_permalink for all products created on or after Jan 9, 2023."
    public init?(productId: String) {
        guard productId.isEmpty == false else { return nil }
        self.productId = productId
    }

    /// Checks validity of Gumroad-issued license key
    /// - Parameters:
    ///   - licenseKey: Non-empty string, preferably sanitized (remember Little Bobby Tables!)
    ///   - incrementUsesCount: Whether Gumroad should increment count of times a license has been checked
    /// - Returns: `true` only if a number of checks passed (see implementation)
    public func isLicenseKeyValid(_ licenseKey: String, incrementUsesCount: Bool = true) async -> Bool {
        guard let request = makeRequest(licenseKey: licenseKey,
                                        incrementUsesCount: incrementUsesCount) else { return false }
        let response: APIResponse? = try? await URLSession.shared.decode(for: request, dateDecodingStrategy: .iso8601)
        guard let success = response?.success, success,
              let purchase = response?.purchase else { return false }

        guard let verifiedKey = purchase.licenseKey, verifiedKey == licenseKey,
              let refunded = purchase.refunded, refunded == false
        else { return false }

        return true
    }

    /// Builds a URLRequest towards Gumroad API, which uses POST
    /// - Parameters:
    ///   - licenseKey: Non-empty string, preferably sanitized (remember Little Bobby Tables!)
    ///   - incrementUsesCount: Whether Gumroad should increment count of times a license has been checked
    func makeRequest(licenseKey: String, incrementUsesCount: Bool = true) -> URLRequest? {
        guard productId.isEmpty == false, licenseKey.isEmpty == false else { return nil }
        guard let baseURL = URL(string: "https://api.gumroad.com/v2/licenses/verify"),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { return nil }

        components.queryItems = [
            URLQueryItem(name: "product_id", value: productId),
            URLQueryItem(name: "license_key", value: licenseKey)
        ]
        if incrementUsesCount == false {
            components.queryItems?.append(URLQueryItem(name: "increment_uses_count", value: "false"))
        }
        guard let query = components.url?.query else { return nil }

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = Data(query.utf8)
        return urlRequest
    }

}
