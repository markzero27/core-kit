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

## Dependency Injection Made Simple

CoreKit comes with a powerful `DependencyInjector` and a Swift-friendly `@Inject` property wrapper. Here’s how easy it is to register and use your services:

### Register Your Dependencies

```swift
DependencyInjector.register(NetworkService<ProductEndpoint>(), key: "productService")
DependencyInjector.register(ProductDataSource() as any ProductDataSourceProtocol)
```

### Inject Anywhere with `@Inject`

```swift
@Inject(key: "productService") private var productService: NetworkService<ProductEndpoint>
@Inject private var productDataSource: ProductDataSourceProtocol
```

No need to manually resolve anything—CoreKit handles it behind the scenes.

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

---

## Get Started Today

CoreKit is open-source and available on GitHub. Check it out, star the repo, and start building robust SwiftUI apps today.

👉 [**https://github.com/markzero27/core-kit**](https://github.com/markzero27/core-kit)

Have questions or feedback? Feel free to connect—I’m always happy to collaborate or help improve the architecture of your SwiftUI projects.

Happy coding! 🚀  
*– Mark Daquis*
