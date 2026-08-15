import XCTest
@testable import HEOSLocalRemote

final class LocalizationTests: XCTestCase {
    func testSwedishAndEnglishResourcesAreBundled() throws {
        let appBundle = Bundle.main
        let swedish = try localizedBundle(language: "sv", in: appBundle)
        let english = try localizedBundle(language: "en", in: appBundle)

        XCTAssertEqual(swedish.localizedString(forKey: "Rum", value: nil, table: "Localizable"), "Rum")
        XCTAssertEqual(english.localizedString(forKey: "Rum", value: nil, table: "Localizable"), "Rooms")
        XCTAssertEqual(english.localizedString(forKey: "Sök efter HEOS-enheter", value: nil, table: "Localizable"), "Search for HEOS devices")
    }

    private func localizedBundle(language: String, in bundle: Bundle) throws -> Bundle {
        let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
