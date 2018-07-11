# FluentSeeder
![Swift](http://img.shields.io/badge/swift-4.1-brightgreen.svg)
![Vapor](http://img.shields.io/badge/vapor-3.0-brightgreen.svg)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
![License](http://img.shields.io/badge/license-MIT-CCCCCC.svg)

FluentSeeder makes it easier to seed Fluent models. For testing purposes, it can create psuedo realistic random data for your models based on their property names and types using  [RandomFactory](https://github.com/Appsaurus/RandomFactory). 

## Installation

**FluentSeeder** is available through [Swift Package Manager](https://swift.org/package-manager/). To install, add the following to your Package.swift file.

```swift
let package = Package(
    name: "YourProject",
    dependencies: [
        ...
        .package(url: "https://github.com/Appsaurus/FluentSeeder", from: "0.1.0"),
    ],
    targets: [
      .testTarget(name: "YourApp", dependencies: ["FluentSeeder", ... ])
    ]
)
        
```
## Usage

**1. Import the library**

```swift
import FluentSeeder
```

**2. Implement Seeder**

Registering and configuration of services, databases, and migrations can be done via overriding `register(services:)`, `configure(databases:)` and `configure(migrations:)` respectively.

```swift

public class ExampleSeeder: Seeder{
	public typealias Database = SQLiteDatabase
	open static func seeds() -> [SeedProtocol]{
		return [
			//Seed models first
			Seed<ExampleModel>(count: 50),
			Seed<ExampleSiblingModel>(count: 25),
			Seed<ExampleChildModel>(count: 10),

			//Then relationships that depend on those models existing
			SiblingSeed<ExampleModelSiblingPivot>(count: 10),
			
			//You can seed parents for each child
			ParentSeed<ExampleModel, ExampleChildModel>(at: \.optionalParentModelId)
			
			//Or if you prefer to seed the relationship in the other direction (possibly for one-to-many relationship)
			ChildSeed<ExampleModel, ExampleChildModel>.init(count: 3, at:  \.optionalParentModelId)
		]
	}
}
```
**3. Add your seeder's migration to the database**

```swift
//Don't forget to add your model mirations first
migrations.add(model: ExampleModel.self, database: .sqlite)
migrations.add(model: ExampleSiblingModel.self, database: .sqlite)
migrations.add(model: ExampleChildModel.self, database: .sqlite)
migrations.add(model: ExampleModelSiblingPivot.self, database: .sqlite)

migrations.add(migration: ExampleSeeder.self, database: .sqlite)
```

### Custom seeds

By supplying a `ModelFactory` to the `Seed` initializer, you can customize how your model is initialized and override the default randmized data. For relationship seeds, you can supply querys to filter which models are included when creating relationships are formed. For `SiblingSeed` you can optionally supply a `leftQuery` and `rightQuery`, and for `ParentSeed` and `ChildSeed` you can optionally supply `parentQuery` and `childQuery`. If no queries are provided, random samples are taken from each seeded model, or all models are iterated depending upon the direction of the seeded relationship. 

## Contributing

We would love you to contribute to **FluentSeeder**, check the [CONTRIBUTING](https://github.com/Appsaurus/FluentSeeder/blob/master/CONTRIBUTING.md) file for more info.

## License

**FluentSeeder** is available under the MIT license. See the [LICENSE](https://github.com/Appsaurus/FluentSeeder/blob/master/LICENSE.md) file for more info.
