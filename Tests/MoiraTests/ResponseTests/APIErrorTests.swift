import Testing
@testable import Moira

struct APIErrorTests {
    @Test("capabilityNotSupportedHasClearDescription")
    func capabilityNotSupportedHasClearDescription() {
        let error = APIError.capabilityNotSupported("Current client does not support uploads.")

        #expect(error.errorDescription == "Capability not supported: Current client does not support uploads.")
    }

    @Test("capabilityNotSupportedSupportsEmptyReason")
    func capabilityNotSupportedSupportsEmptyReason() {
        let error = APIError.capabilityNotSupported("")

        #expect(error.errorDescription == "Capability not supported.")
    }
}
