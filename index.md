---
layout: default
title: Introducing CoreKit
permalink: /
---

# Introducing CoreKit: A Modular Clean Architecture Foundation for SwiftUI  
*by Mark Daquis*  

Building scalable and testable iOS apps with SwiftUI can be challenging, especially when it comes to managing dependencies and structuring layers like networking, data sources, repositories, and use cases. That’s exactly why I created [**CoreKit**](https://github.com/markzero27/core-kit): a lightweight, modular package designed to simplify and supercharge your app architecture.

## What is CoreKit?

**CoreKit** is a modular package tailored for SwiftUI projects following Clean Architecture principles. It helps developers streamline dependency injection and manage network services with minimal code complexity. Whether you're building a small app or a large-scale solution, CoreKit gives you the flexibility and clarity needed to scale.

## Key Features

- 🔧 **Lightweight Dependency Injection** with `@Inject`
- 🌐 **Protocol-Oriented Networking Layer**
- 🧱 **Support for Clean Architecture Layers** (Data Source, Repository, Use Case)
- 🧪 **Test-Friendly by Design**

---

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

Once dependencies are registered, you typically do **not** need to manually call `resolve()` thanks to the built-in `@Inject` property wrapper provided by CoreKit.

```swift
@Inject(key: "productService") private var productService: NetworkService<ProductEndpoint>
@Inject private var productDataSource: ProductDataSourceProtocol
```

In this example:
- `productService` is automatically resolved using the key `"productService"`.
- `productDataSource` is resolved using the type `ProductDataSourceProtocol` (since it was registered without a key).


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

---

## Powerful Network Layer

With CoreKit, defining API endpoints is easy and consistent. Just conform your enums to `NetworkEndpoint`, and you’re good to go.

```swift
enum ProductEndpoint: NetworkEndpoint {
    case listProducts
    case getProduct(id: String)
    case createProduct(name: String, price: Double)

    var path: String {
        switch self {
        case .listProducts: return "/products"
        case let .getProduct(id): return "/products/\(id)"
        case .createProduct: return "/products"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listProducts, .getProduct: return .get
        case .createProduct: return .post
        }
    }

    var headers: [String: String]? {
        var headers = ["Content-Type": "application/json"]
        if let token = NetworkSession.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    var body: [String: Any]? {
        switch self {
        case let .createProduct(name, price):
            return ["name": name, "price": price]
        default:
            return nil
        }
    }
}
```

Then use it like this:

```swift
let productService = NetworkService<ProductEndpoint>()
let products = try await productService.request(.listProducts)
```

---

## Clean Architecture, Done Right

CoreKit follows Clean Architecture by encouraging the use of layers:

- **Data Sources** – Wrap the networking logic
- **Repositories** – Abstract and centralize domain logic
- **Use Cases** – Encapsulate business logic

This makes your code highly modular and testable.

---

### Unit Testing with `@Inject`

When testing components that use dependency injection, you can mock the dependencies and inject them using `@Inject`. This allows you to test the business logic in isolation without relying on actual network calls or external services.


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

---

## Get Started Today

CoreKit is open-source and available on GitHub. Check it out, star the repo, and start building robust SwiftUI apps today.

👉 [**https://github.com/markzero27/core-kit**](https://github.com/markzero27/core-kit)

Have questions or feedback? Feel free to connect—I’m always happy to collaborate or help improve the architecture of your SwiftUI projects.

Happy coding! 🚀  
*– Mark Daquis*
