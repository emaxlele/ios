import BitwardenKit
import BitwardenKitMocks
import XCTest

@testable import AuthenticatorShared

class StateServiceTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var dataStore: DataStore!
    var subject: DefaultStateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appSettingsStore = MockAppSettingsStore()
        dataStore = DataStore(errorReporter: MockErrorReporter(), storeType: .memory)

        subject = DefaultStateService(
            appSettingsStore: appSettingsStore,
            dataStore: dataStore,
        )
    }

    override func tearDown() {
        super.tearDown()

        appSettingsStore = nil
        dataStore = nil
        subject = nil
    }

    // MARK: Tests

    /// `getFlightRecorderData()` returns the data for the flight recorder.
    func test_getFlightRecorderData() async throws {
        let storedFlightRecorderData = FlightRecorderData()
        appSettingsStore.flightRecorderData = storedFlightRecorderData

        let flightRecorderData = await subject.getFlightRecorderData()
        XCTAssertEqual(flightRecorderData, storedFlightRecorderData)
    }

    /// `getFlightRecorderData()` returns `nil` if there's no stored data for the flight recorder.
    func test_getFlightRecorderData_notSet() async throws {
        appSettingsStore.flightRecorderData = nil

        let flightRecorderData = await subject.getFlightRecorderData()
        XCTAssertNil(flightRecorderData)
    }

    /// `getLocalUserDataKeyStates(userId:)` returns stored key states for a user.
    func test_getLocalUserDataKeyStates() async {
        let states: [String: UserKeyData] = ["k1": UserKeyData(wrappedKey: "key1")]
        appSettingsStore.localUserDataKeyStatesByUserId["1"] = states
        let result = await subject.getLocalUserDataKeyStates(userId: "1")
        XCTAssertEqual(result, states)
    }

    /// `getLocalUserDataKeyStates(userId:)` returns `nil` when no states are stored.
    func test_getLocalUserDataKeyStates_notSet() async {
        let result = await subject.getLocalUserDataKeyStates(userId: "1")
        XCTAssertNil(result)
    }

    /// `setFlightRecorderData(_:)` sets the data for the flight recorder.
    func test_setFlightRecorderData() async throws {
        let flightRecorderData = FlightRecorderData()
        await subject.setFlightRecorderData(flightRecorderData)
        XCTAssertEqual(appSettingsStore.flightRecorderData, flightRecorderData)
    }

    /// `setLocalUserDataKeyState(id:value:userId:)` stores a single key state.
    func test_setLocalUserDataKeyState() async {
        await subject.setLocalUserDataKeyState(id: "k1", value: UserKeyData(wrappedKey: "key1"), userId: "1")
        XCTAssertEqual(appSettingsStore.localUserDataKeyStatesByUserId["1"], ["k1": UserKeyData(wrappedKey: "key1")])
    }

    /// `setBulkLocalUserDataKeyStates(_:userId:)` merges multiple key states atomically.
    func test_setBulkLocalUserDataKeyStates() async {
        let values: [String: UserKeyData] = [
            "k1": UserKeyData(wrappedKey: "key1"),
            "k2": UserKeyData(wrappedKey: "key2"),
        ]
        await subject.setBulkLocalUserDataKeyStates(values, userId: "1")
        XCTAssertEqual(appSettingsStore.localUserDataKeyStatesByUserId["1"], values)
    }

    /// `removeLocalUserDataKeyState(id:userId:)` removes a single key state.
    func test_removeLocalUserDataKeyState() async {
        await subject.setLocalUserDataKeyState(id: "k1", value: UserKeyData(wrappedKey: "key1"), userId: "1")
        await subject.removeLocalUserDataKeyState(id: "k1", userId: "1")
        XCTAssertNil(appSettingsStore.localUserDataKeyStatesByUserId["1"])
    }

    /// `removeBulkLocalUserDataKeyStates(keys:userId:)` removes multiple key states atomically.
    func test_removeBulkLocalUserDataKeyStates() async {
        let values: [String: UserKeyData] = [
            "k1": UserKeyData(wrappedKey: "key1"),
            "k2": UserKeyData(wrappedKey: "key2"),
            "k3": UserKeyData(wrappedKey: "key3"),
        ]
        await subject.setBulkLocalUserDataKeyStates(values, userId: "1")
        await subject.removeBulkLocalUserDataKeyStates(keys: ["k1", "k2"], userId: "1")
        XCTAssertEqual(appSettingsStore.localUserDataKeyStatesByUserId["1"], ["k3": UserKeyData(wrappedKey: "key3")])
    }

    /// `removeAllLocalUserDataKeyStates(userId:)` clears all stored states.
    func test_removeAllLocalUserDataKeyStates() async {
        await subject.setLocalUserDataKeyState(id: "k1", value: UserKeyData(wrappedKey: "key1"), userId: "1")
        await subject.removeAllLocalUserDataKeyStates(userId: "1")
        XCTAssertNil(appSettingsStore.localUserDataKeyStatesByUserId["1"])
    }

    /// `setFlightRecorderData(_:)` clears the data when nil is passed.
    func test_setFlightRecorderData_nil() async throws {
        let flightRecorderData = FlightRecorderData()
        await subject.setFlightRecorderData(flightRecorderData)
        XCTAssertEqual(appSettingsStore.flightRecorderData, flightRecorderData)

        await subject.setFlightRecorderData(nil)
        XCTAssertNil(appSettingsStore.flightRecorderData)
    }
}
