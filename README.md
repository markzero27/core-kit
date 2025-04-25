# core-kit

CoreKit by Mark Daquis is a modular package for iOS, designed specifically for SwiftUI Clean Architecture. It simplifies dependency injection and network service handling. This package offers a flexible, reusable foundation to streamline app architecture and improve code maintainability across SwiftUI-based projects.

## Usage

### Dependency Injection with `DependencyInjector`

CoreKit provides a simple way to manage dependencies using the `DependencyInjector` class. This class allows you to register and resolve dependencies throughout your app.

#### Registering Dependencies

To register a dependency, you use the `register()` method. If you provide a `key`, the dependency will be registered with that key; otherwise, it will be registered using the type of the dependency as the key.

Here’s how you can register dependencies:

```swift
DependencyInjector.register(NetworkService<ProductEndpoint>(), key: "productService")
DependencyInjector.register(ProductDataSource() as any ProductDataSourceProtocol)
```

In this example:
- `NetworkService<ProductEndpoint>()` is registered with the key `"productService"`.
- `ProductDataSource()` is registered using the type `ProductDataSourceProtocol` as the key.

#### Resolving Dependencies
 
Once registered, you can resolve the dependency using the `resolve()` method. If you used a key while registering the dependency, you must provide the same key when resolving it.

```swift
let productService: NetworkService<ProductEndpoint> = DependencyInjector.resolve(key: "productService")
let productDataSource: ProductDataSourceProtocol = DependencyInjector.resolve()
```

In this example:
- `productService` is resolved using the key `"productService"`.
- `productDataSource` is resolved using the type `ProductDataSourceProtocol` (since it was registered without a key).

If a dependency is not found, the `resolve()` method will trigger a fatal error. Ensure that dependencies are registered correctly before resolving them.

To register dependencies using CoreKit, define a `DependencyRegistry` enum or struct and implement a `registerAll()` method. Below is a generic example showing how to register network services, data sources, repositories, and use cases:

```swift
enum DependencyRegistry {
    static func registerAll() {
        registerNetworkServices()
        registerDataSources()
        registerRepositories()
        registerUseCases()
    }

    static func registerNetworkServices() {
        DependencyInjector.register(NetworkService<ProductEndpoint>(), key: "product")
    }

    static func registerDataSources() {
        DependencyInjector.register(ProductDataSource() as any ProductDataSourceProtocol)
    }

    static func registerRepositories() {
        DependencyInjector.register(ProductRepository() as any ProductRepositoryProtocol)
    }

    static func registerUseCases() {
        DependencyInjector.register(GetProductUseCase() as any GetProductUseCaseProtocol)
    }
}
```

Then, in your app’s initialization phase (e.g., inside `AppDelegate` or `@main` struct), call:

```swift
DependencyRegistry.registerAll()
```

This ensures all required services are properly set up before the app begins executing business logic.

## Networking

CoreKit supports a flexible and extensible way to define and use API endpoints using the `NetworkEndpoint` protocol.

To define your API endpoints, create an enum that conforms to `NetworkEndpoint`. Each case in the enum represents an API action. Here’s an example:

```swift
enum ProductEndpoint {
    case listProducts
    case getProduct(id: String)
    case createProduct(name: String, price: Double)
}

extension ProductEndpoint: NetworkEndpoint {
    var path: String {
        switch self {
        case .listProducts:
            return "/products"
        case let .getProduct(id):
            return "/products/\(id)"
        case .createProduct:
            return "/products"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listProducts, .getProduct:
            return .get
        case .createProduct:
            return .post
        }
    }

    var headers: [String : String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = NetworkSession.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    var body: [String : Any]? {
        switch self {
        case let .createProduct(name, price):
            return ["name": name, "price": price]
        default:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        return nil
    }
}
```

To use the endpoint, initialize a `NetworkService` with your endpoint enum and call it with async/await:

```swift
let productService = NetworkService<ProductEndpoint>()
let products = try await productService.request(.listProducts)
```

This setup ensures your networking layer is cleanly separated and easy to test or extend.

### Using NetworkService in a Data Source

Once you’ve defined an endpoint, you can inject and use `NetworkService` in your data source layer. This keeps your data-fetching logic cleanly separated and easy to mock for testing. Here's a simple example:

```swift
protocol ProductDataSourceProtocol {
    func fetchAllProducts() async throws -> [Product]
    func fetchProductById(_ id: String) async throws -> Product
}

final class ProductDataSource: ProductDataSourceProtocol {

    // Inject the appropriate NetworkService using CoreKit's `@Inject`
    @Inject(key: "product")
    private var networkService: NetworkService<ProductEndpoint>
    
    func fetchAllProducts() async throws -> [Product] {
        return try await networkService.request(.listProducts)
    }

    func fetchProductById(_ id: String) async throws -> Product {
        return try await networkService.request(.getProduct(id: id))
    }
}
```

This structure allows your data source to focus on specific domain tasks while keeping networking logic encapsulated in the service layer.

### Repository Layer

The repository interacts with the data source to fetch products and manage related actions. Here’s a sample repository implementation:

```swift
final class ProductRepository: ProductRepositoryProtocol {
    
    // MARK: - Dependencies
    @Inject private var remoteDataSource: ProductDataSourceProtocol
    
    func getProducts() async throws -> [Product] {
        return try await remoteDataSource.fetchAllProducts()
    }
    
    func getProductById(id: String) async throws -> Product {
        return try await remoteDataSource.fetchProductById(id)
    }
    
    func createProduct(name: String, price: Double) async throws {
        try await remoteDataSource.createProduct(name: name, price: price)
    }
}
```

### Connecting Use Case to Repository
Once you've set up your endpoints, data source, and repository, you can create a use case to encapsulate the business logic. The use case will connect to the repository, which in turn interacts with the data source. Here’s an example of how to use a use case to fetch products:

```swift
protocol GetProductsUseCaseProtocol {
    func execute() async throws -> [Products]
}

final class GetProductsUseCase: GetProductsUseCaseProtocol {
    // MARK: - Dependencies
    @Inject private var repository: ProductRepositoryProtocol
    
    func execute() async throws -> [Products] {
        return try await repository.getProducts()
    }
}
```

#### Example of Dependency Usage in a View Model

You can inject dependencies into your view model by resolving them when needed. Here’s how it might look in a view model:

```swift
@Inject private var getProductUseCase: GetProductUseCaseProtocol

func loadProducts() async {
    do {
        let products = try await getProductUseCase.execute()
        // Update your state/UI with the products
    } catch {
        // Handle error
        print("Failed to load products: \(error)")
    }
}

func loadProductDetails(id: String) async {
    do {
        let product = try await getProductUseCase.executeForProduct(id: id)
        // Update your state/UI with the product details
    } catch {
        // Handle error
        print("Failed to load product details: \(error)")
    }
}
```

Here:
- `getProductUseCase` is injected using `@Inject`.
- The use case is resolved using `DependencyInjector` to fetch products and update the UI.


### Unit Testing with `@Inject`

When testing components that use dependency injection, you can mock the dependencies and inject them using `@Inject`. This allows you to test the business logic in isolation without relying on actual network calls or external services.

This pattern ensures that your repository, use case, and other components can be unit tested without relying on external systems.

#### Unit Testing Dependencies with `@Inject` and `DependencyInjector`

To unit test dependencies that are resolved using `@Inject`, you can register your mock implementations with the `DependencyInjector` before running your tests. This ensures that when `@Inject` is used in your components, the mock instance is injected instead of the real one.

Here's how you can do it:

```swift
import XCTest
@testable import CoreKit

class ProductRepositoryInjectTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Register the mock data source for injection
        let mockProductDataSource = MockProductDataSource()
        DependencyInjector.register(mockProductDataSource as ProductDataSourceProtocol)
    }

    override func tearDown() {
        // Optionally clear registered dependencies if your DependencyInjector supports it
        super.tearDown()
    }

    func testRepositoryUsesInjectedMock() async throws {
        // The repository will use @Inject to resolve ProductDataSourceProtocol, which is registered as a mock
        let repository = ProductRepository()
        let mockProducts = [Product(id: "42", name: "Injected Mock", price: 42.0)]

        // If needed, retrieve the mock to set its properties
        let mock = DependencyInjector.resolve() as MockProductDataSource
        mock.mockProducts = mockProducts

        let products = try await repository.getProducts()
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.name, "Injected Mock")
    }
}
```

**Key Steps:**
- Register your mock with `DependencyInjector` before the test.
- When `@Inject` is used in your component (e.g., repository), it will resolve the mock instead of the real implementation.
- This pattern allows you to test components that use `@Inject` without modifying their constructors or production code.

This approach ensures that your view models are decoupled from the instantiation of dependencies, promoting cleaner, more maintainable code.
