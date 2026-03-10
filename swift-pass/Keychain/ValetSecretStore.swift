import Valet

struct ValetSecretStore: SecretStore {
    let configuration: KeychainConfiguration

    private let valet: Valet

    init(configuration: KeychainConfiguration = .default) {
        self.configuration = configuration
        valet = Valet.valet(
            with: configuration.valetIdentifier,
            accessibility: configuration.accessibility
        )
    }

    func canAccessKeychain() -> Bool {
        valet.canAccessKeychain()
    }
}
