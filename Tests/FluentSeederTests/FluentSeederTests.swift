import XCTest
@testable import FluentSeeder
import FluentTestModels
import Vapor
import Fluent


fileprivate let exampleModelCount = 50
fileprivate let exampleSiblingModelCount = 25
fileprivate let exampleChildModelCount = 10
fileprivate let siblingsPerExampleModel = 10

final class FluentSeederTests: FluentTestModels.TestCase {



	//MARK: Tests
	func testSeed() throws {
//        XCTAssert(model: KitchenSink.self, hasCount: exampleModelCount, on: app.db)
//		XCTAssert(model: StudentModel.self, hasCount: exampleSiblingModelCount, on: app.db)
//		XCTAssert(model: ExampleChildModel.self, hasCount: exampleChildModelCount, on: app.db)
	}

	func testSiblingsSeed() throws{
        let models = try StudentModel.query(on: app.db).all().wait()
		try models.forEach { (model) in
            XCTAssertEqual(try model.classes.query(on: app.db).count().wait(), siblingsPerExampleModel)
		}
	}

	func testParentSeed() throws{
		let children = try ExampleChildModel.query(on: request).all().wait()
		try children.forEach { (child) in
			XCTAssertNotNil(try child.optionalParentModel?.query(on: request).first().wait())
		}
	}
}

public class ExampleSeeder: Seeder{
	public typealias Database = SQLiteDatabase
	open static func seeds() -> [SeedProtocol]{
		return [
			//Seed models first
			Seed<ExampleModel>(count: exampleModelCount),
			Seed<ExampleSiblingModel>(count: exampleSiblingModelCount),
			Seed<ExampleChildModel>(count: exampleChildModelCount),

			//Then relationships that depend on those models existing
			SiblingSeed<ExampleModelSiblingPivot>(count: siblingsPerExampleModel),
			ParentSeed<ExampleModel, ExampleChildModel>(at: \.optionalParentModelId)
		]
	}
}
