import XCTest
@testable import FluentSeeder
import FluentTestModels
import Vapor
import Fluent
import FluentTestUtils
import CodableExtensions

fileprivate let kitchenSinkModelCount = 5
fileprivate let studentModelCount = 10
fileprivate let classModelCount = 3
fileprivate let siblingsPerExampleModel = 5
fileprivate let parentModelCount = 5
fileprivate let childModelCount = 10


final class FluentSeederTests: FluentTestModels.TestCase {
    override public func configure(_ databases: Databases) throws {
        databases.use(.sqlite(.memory, connectionPoolTimeout: .minutes(2)), as: .sqlite)
    }

    override public func migrate(_ migrations: Migrations) throws {
        try super.migrate(migrations)
        migrations.add(ExampleSeeder())
    }

	//MARK: Tests
	func testSeed() throws {
        XCTAssert(model: KitchenSink.self, hasCount: kitchenSinkModelCount, on: app.db)
		XCTAssert(model: StudentModel.self, hasCount: studentModelCount, on: app.db)
        XCTAssert(model: ClassModel.self, hasCount: classModelCount, on: app.db)
        XCTAssert(model: ParentModel.self, hasCount: parentModelCount, on: app.db)
		XCTAssert(model: ChildModel.self, hasCount: childModelCount, on: app.db)
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
    public func seeds(on database: Database) -> [SeedProtocol] {
        let factory = ModelFactory.fluentFactory()
        factory.config.register(enumType: TestIntEnum.self)
        factory.config.register(enumType: TestStringEnum.self)
        factory.config.register(enumType: TestRawStringEnum.self)
        factory.config.register(enumType: TestRawIntEnum.self)
        return [
            //Seed models first
            Seed<KitchenSink>(count: kitchenSinkModelCount, factory: factory),
            Seed<StudentModel>(count: studentModelCount, factory: factory),
            Seed<ClassModel>(count: classModelCount, factory: factory),
            Seed<ParentModel>(count: parentModelCount, factory: factory),
            Seed<ChildModel>(count: childModelCount, factory: factory),

//            //Then relationships that depend on those models existing
            SiblingSeed<ClassModel, StudentModel, EnrollmentModel>(count: siblingsPerExampleModel,
                                                                   through: \.$classes),
            ParentSeed<ParentModel, ChildModel>(at: \ChildModel.$parent)
        ]
	}
}
