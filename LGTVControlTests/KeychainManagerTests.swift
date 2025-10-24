import XCTest
@testable import LGTVControl

final class KeychainManagerTests: XCTestCase {
    
    var keychain: KeychainManager!
    let testService = "com.DaraConsultingInc.LGTVRemoteWidget.test"
    let testAccount = "testAccount"
    
    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        // Clean up any existing test data
        try? keychain.delete(service: testService, account: testAccount)
    }
    
    override func tearDown() {
        // Clean up test data
        try? keychain.delete(service: testService, account: testAccount)
        keychain = nil
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func testSaveCredentials() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "test-client-key-12345"
        )
        
        // When
        try keychain.save(credentials, service: testService, account: testAccount)
        
        // Then - no exception thrown means success
        XCTAssertNoThrow(try keychain.load(TVCredentials.self, service: testService, account: testAccount))
    }
    
    func testSaveOverwritesExistingData() throws {
        // Given
        let credentials1 = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "old-key"
        )
        let credentials2 = TVCredentials(
            ipAddress: "192.168.1.101",
            macAddress: "11:22:33:44:55:66",
            clientKey: "new-key"
        )
        
        // When
        try keychain.save(credentials1, service: testService, account: testAccount)
        try keychain.save(credentials2, service: testService, account: testAccount)
        
        // Then
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        XCTAssertEqual(loaded?.ipAddress, "192.168.1.101")
        XCTAssertEqual(loaded?.clientKey, "new-key")
    }
    
    // MARK: - Load Tests
    
    func testLoadCredentials() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "10.0.0.14",
            macAddress: "34:E6:E6:F9:05:50",
            clientKey: "9ba71d29c353cf0bdcc00c4b0a8cc189"
        )
        try keychain.save(credentials, service: testService, account: testAccount)
        
        // When
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.ipAddress, credentials.ipAddress)
        XCTAssertEqual(loaded?.macAddress, credentials.macAddress)
        XCTAssertEqual(loaded?.clientKey, credentials.clientKey)
    }
    
    func testLoadNonExistentReturnsNil() throws {
        // When
        let loaded = try keychain.load(TVCredentials.self, service: "nonexistent", account: "nonexistent")
        
        // Then
        XCTAssertNil(loaded)
    }
    
    func testLoadAfterDeleteReturnsNil() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        try keychain.save(credentials, service: testService, account: testAccount)
        
        // When
        try keychain.delete(service: testService, account: testAccount)
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        
        // Then
        XCTAssertNil(loaded)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteCredentials() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        try keychain.save(credentials, service: testService, account: testAccount)
        
        // When
        try keychain.delete(service: testService, account: testAccount)
        
        // Then
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        XCTAssertNil(loaded)
    }
    
    func testDeleteNonExistentDoesNotThrow() {
        // When/Then
        XCTAssertNoThrow(try keychain.delete(service: "nonexistent", account: "nonexistent"))
    }
    
    func testDeleteTwiceDoesNotThrow() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        try keychain.save(credentials, service: testService, account: testAccount)
        
        // When/Then
        XCTAssertNoThrow(try keychain.delete(service: testService, account: testAccount))
        XCTAssertNoThrow(try keychain.delete(service: testService, account: testAccount))
    }
    
    // MARK: - Edge Cases
    
    func testSaveCredentialsWithoutClientKey() throws {
        // Given - credentials without client key (not yet paired)
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )
        
        // When
        try keychain.save(credentials, service: testService, account: testAccount)
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.ipAddress, credentials.ipAddress)
        XCTAssertNil(loaded?.clientKey)
    }
    
    func testSaveEmptyStrings() throws {
        // Given
        let credentials = TVCredentials(
            ipAddress: "",
            macAddress: "",
            clientKey: ""
        )
        
        // When
        try keychain.save(credentials, service: testService, account: testAccount)
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.ipAddress, "")
        XCTAssertEqual(loaded?.macAddress, "")
        XCTAssertEqual(loaded?.clientKey, "")
    }
    
    func testSaveVeryLongClientKey() throws {
        // Given - simulate a very long client key
        let longKey = String(repeating: "a", count: 10000)
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: longKey
        )
        
        // When
        try keychain.save(credentials, service: testService, account: testAccount)
        let loaded = try keychain.load(TVCredentials.self, service: testService, account: testAccount)
        
        // Then
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.clientKey?.count, 10000)
    }
    
    // MARK: - Multiple Account Tests
    
    func testMultipleAccountsIndependent() throws {
        // Given
        let credentials1 = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "key1"
        )
        let credentials2 = TVCredentials(
            ipAddress: "192.168.1.101",
            macAddress: "11:22:33:44:55:66",
            clientKey: "key2"
        )
        
        // When
        try keychain.save(credentials1, service: testService, account: "account1")
        try keychain.save(credentials2, service: testService, account: "account2")
        
        // Then
        let loaded1 = try keychain.load(TVCredentials.self, service: testService, account: "account1")
        let loaded2 = try keychain.load(TVCredentials.self, service: testService, account: "account2")
        
        XCTAssertEqual(loaded1?.clientKey, "key1")
        XCTAssertEqual(loaded2?.clientKey, "key2")
        
        // Cleanup
        try keychain.delete(service: testService, account: "account1")
        try keychain.delete(service: testService, account: "account2")
    }
    
    func testDeleteOneAccountDoesNotAffectOther() throws {
        // Given
        let credentials1 = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "key1"
        )
        let credentials2 = TVCredentials(
            ipAddress: "192.168.1.101",
            macAddress: "11:22:33:44:55:66",
            clientKey: "key2"
        )
        
        try keychain.save(credentials1, service: testService, account: "account1")
        try keychain.save(credentials2, service: testService, account: "account2")
        
        // When
        try keychain.delete(service: testService, account: "account1")
        
        // Then
        let loaded1 = try keychain.load(TVCredentials.self, service: testService, account: "account1")
        let loaded2 = try keychain.load(TVCredentials.self, service: testService, account: "account2")
        
        XCTAssertNil(loaded1)
        XCTAssertNotNil(loaded2)
        XCTAssertEqual(loaded2?.clientKey, "key2")
        
        // Cleanup
        try keychain.delete(service: testService, account: "account2")
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadInvalidDataTypeThrows() {
        // Given - save a string, try to load as credentials
        struct TestString: Codable {
            let value: String
        }
        
        do {
            try keychain.save(TestString(value: "test"), service: testService, account: testAccount)
            
            // When/Then - should throw encoding error when trying to decode as TVCredentials
            XCTAssertThrowsError(try keychain.load(TVCredentials.self, service: testService, account: testAccount)) { error in
                XCTAssertTrue(error is KeychainError)
                if case KeychainError.encodingFailed = error {
                    // Expected error
                } else {
                    XCTFail("Expected KeychainError.encodingFailed, got \(error)")
                }
            }
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testSavePerformance() {
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "test-key"
        )
        
        measure {
            for i in 0..<100 {
                try? keychain.save(credentials, service: "\(testService)_perf", account: "account\(i)")
            }
        }
        
        // Cleanup
        for i in 0..<100 {
            try? keychain.delete(service: "\(testService)_perf", account: "account\(i)")
        }
    }
    
    func testLoadPerformance() {
        // Setup
        let credentials = TVCredentials(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            clientKey: "test-key"
        )
        try? keychain.save(credentials, service: testService, account: testAccount)
        
        measure {
            for _ in 0..<100 {
                _ = try? keychain.load(TVCredentials.self, service: testService, account: testAccount)
            }
        }
    }
}
