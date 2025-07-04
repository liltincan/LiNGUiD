import Foundation

final class DependencyContainer {
    static let shared = DependencyContainer()
    private init() {}

    func registerAll() {
        register(AuthService.self) { FirebaseAuthService() }
        register(VideoRepository.self) { FirestoreVideoRepository() }
        register(FirestoreVideoRepository.self) { FirestoreVideoRepository() }

    }

    private var factories = [String: () -> Any]()

    func register<Service>(_ type: Service.Type, factory: @escaping () -> Service) {
        factories[String(describing: type)] = factory
    }

    func resolve<Service>() -> Service {
        let key = String(describing: Service.self)
        guard let factory = factories[key], let service = factory() as? Service else {
            fatalError("No factory for \(key)")
        }
        return service
    }
}
