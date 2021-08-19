import XCTest
@testable import FluentSeeder
import FluentTestModels
import Vapor
import Fluent
import FluentTestUtils

fileprivate let kitchenSinkModelCount = 50
fileprivate let studentModelCount = 200
fileprivate let classModelCount = 25
fileprivate let siblingsPerExampleModel = 10
fileprivate let parentModelCount = 10
fileprivate let childModelCount = 20


final class FluentSeederTests: FluentTestModels.TestCase {


    override public func migrate(_ migrations: Migrations) throws {
        try super.migrate(migrations)
        migrations.add(ExampleSeeder())
    }

	//MARK: Tests
	func testSeed() throws {
        XCTAssert(model: KitchenSink.self, hasCount: kitchenSinkModelCount, on: app.db)
//		XCTAssert(model: StudentModel.self, hasCount: studentModelCount, on: app.db)
//        XCTAssert(model: ClassModel.self, hasCount: classModelCount, on: app.db)
//        XCTAssert(model: ParentModel.self, hasCount: parentModelCount, on: app.db)
//		XCTAssert(model: ChildModel.self, hasCount: childModelCount, on: app.db)
	}

	func testSiblingsSeed() throws{
        
        let models = try StudentModel.query(on: app.db).all().wait()
		try models.forEach { (model) in
            let classes = try model.$classes.query(on: app.db).all().wait()
            XCTAssertEqual(classes.count, siblingsPerExampleModel)
		}
	}

	func testParentSeed() throws{
        let children = try ChildModel.query(on: app.db).all().wait()
		try children.forEach { (child) in
			XCTAssertNotNil(try child.$parent.query(on: app.db).first().wait())
		}
	}
}

public class ExampleSeeder: Seeder{
	open func seeds() -> [SeedProtocol]{
        do {
            try RandomFactory.shared.register(enumType: TestIntEnum.self)
            try RandomFactory.shared.register(enumType: TestStringEnum.self)
            try RandomFactory.shared.register(enumType: TestRawStringEnum.self)
            try RandomFactory.shared.register(enumType: TestRawIntEnum.self)
        }
        catch {
            fatalError("Failed to register enums")
        }

		return [
			//Seed models first
			Seed<KitchenSink>(count: kitchenSinkModelCount, factory: .fluentFactory()),
            Seed<StudentModel>(count: studentModelCount, factory: .fluentFactory()),
            Seed<ClassModel>(count: classModelCount, factory: .fluentFactory()),
//            Seed<ParentModel>(count: parentModelCount),
//			Seed<ChildModel>(count: childModelCount),

			//Then relationships that depend on those models existing
            SiblingSeed<ClassModel, StudentModel, EnrollmentModel>(count: siblingsPerExampleModel, through: \.$classes),
//			ParentSeed<ParentModel, ChildModel>(at: \ChildModel.$parent)
		]
	}
}
import RandomFactory
import Runtime

extension RandomDataGenerator.Config {
    public func register<E: CaseIterable & RawRepresentable>(enumType: E.Type) {
        let name = try! Runtime.typeInfo(of: enumType).name
        enumFactory[name] = { E.allCases.randomElement()!.rawValue }
    }
}
extension ModelFactory {
    static func fluentFactory<M: Model>() -> ModelFactory<M> {
        let config = RandomDataGenerator.Config()
        config.register(enumType: TestIntEnum.self)
        config.register(enumType: TestStringEnum.self)
        config.register(enumType: TestRawStringEnum.self)
        config.register(enumType: TestRawIntEnum.self)
        
        config.codableKeyMapper = { key in
            if key.starts(with: "_") {
                return String(key.dropFirst())
            }
            return key
        }
        config.overrides = { property in
//            if property.name == "_buffer" {
//                return RandomFactory.explicitNil
//            }
            if let generatable = property.type as? RandomGeneratable.Type{
                if generatable.shouldGenerate {
                    let type = generatable.generatableType
                    let factory = RandomFactory(config: config)
                    return try! factory.generator.randomValue(ofType: type)
                }
                else {
                    return RandomFactory.explicitNil
                }
            }
            return nil //Let the default behavior generate a random value for this property
        }
        return .randomWith(config: config)
//        return .randomWith( { property in
////            if property.name == "_buffer" {
////                return RandomFactory.explicitNil
////            }
//            if let generatable = property.type as? RandomGeneratable.Type{
//                if generatable.shouldGenerate {
//                    let type = generatable.generatableType
//                    return try! RandomFactory.shared.generator.randomValue(ofType: type)
//                }
//                else {
//                    return RandomFactory.explicitNil
//                }
//            }
//            return nil //Let the default behavior generate a random value for this property
//        }
//        return .custom (initializer: {
//            return try! RandomFactory.shared.randomized(type: M.self, overrides: { (property) -> Any? in
//
////                if property.type == Optional<M.IDValue>.self{
////                    return RandomFactory.explicitNil
////                }
//
//                if let generatable = property.type as? RandomGeneratable.Type{
//                    if generatable.shouldGenerate {
//                        let type = generatable.generatableType
//                        return try! RandomFactory.shared.generator.randomValue(ofType: type, for: property)
//                    }
//                    else {
//                        return RandomFactory.explicitNil
//                    }
//                }
//
////                let genericTypes = try! typeInfo(of: property.type).genericTypes
////                if genericTypes.count == 2, genericTypes.first == M.self {
////                    return try! RandomFactory.shared.generator.randomValue(ofType: type(of: genericTypes[1]), for: property)
////                }
//
//                return nil //Let the default behavior generate a random value for this property
//            })
//        })
    }
}

protocol RandomGeneratable {
    static var shouldGenerate: Bool { get }
    static var generatableType: Any.Type { get }
}
extension RandomGeneratable {
    static var shouldGenerate: Bool { true }
}
extension FieldProperty: RandomGeneratable {
    static var generatableType: Any.Type {
        return Value.self
    }
}

extension OptionalFieldProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}

extension EnumProperty: RandomGeneratable {
    static var generatableType: Any.Type {
        return Value.self
    }
}

extension OptionalEnumProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}


extension ParentProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}

extension GroupProperty: RandomGeneratable {
    static var generatableType: Any.Type {
        return Value.self
    }
}


extension TimestampProperty: RandomGeneratable {
    static var generatableType: Any.Type {
        return Value.self
    }
}

extension OptionalParentProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}

extension ChildrenProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}

extension OptionalChildProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}


extension IDProperty: RandomGeneratable {
    static var shouldGenerate: Bool { false }
    static var generatableType: Any.Type {
        return Never.self
    }
}
