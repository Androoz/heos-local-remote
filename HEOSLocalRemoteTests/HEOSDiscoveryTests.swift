import XCTest
@testable import HEOSLocalRemote

final class HEOSDiscoveryTests: XCTestCase {
    func testParsesDenonSSDPResponse() {
        let response = """
        HTTP/1.1 200 OK\r
        LOCATION: http://192.168.1.42:60006/upnp/desc/aios_device/aios_device.xml\r
        SERVER: Linux UPnP/1.0 Denon/1.0\r
        USN: uuid:example::urn:schemas-denon-com:device:ACT-Denon:1\r
        \r

        """
        let device = HEOSDiscoveryService.parseResponse(Data(response.utf8))
        XCTAssertEqual(device?.host, "192.168.1.42")
        XCTAssertEqual(device?.server, "Linux UPnP/1.0 Denon/1.0")
    }

    func testIgnoresNonSuccessResponse() {
        XCTAssertNil(HEOSDiscoveryService.parseResponse(Data("NOTIFY * HTTP/1.1\r\n\r\n".utf8), fallbackHost: "192.168.1.42"))
    }
}
