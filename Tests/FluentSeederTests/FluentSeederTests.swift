import XCTest
@testable import FluentSeeder
import FluentTestUtils
import Vapor
import Fluent
import FluentSQLite

fileprivate let exampleModelCount = 50
fileprivate let exampleSiblingModelCount = 25
fileprivate let exampleChildModelCount = 10
fileprivate let siblingsPerExampleModel = 10

final class FluentSeederTests: FluentTestCase {
	//MARK: Linux Testing
	static var allTests = [
		("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
		("testSeed", testSeed),
		("testSiblingsSeed", testSiblingsSeed),
		("testParentSeed", testParentSeed)
	]

	func testLinuxTestSuiteIncludesAllTests(){
		assertLinuxTestCoverage(tests: type(of: self).allTests)
	}

	let sqlite: SQLiteDatabase = try! SQLiteDatabase(storage: .memory)

    public override func register(_ services: inout Services) throws {
		try services.register(FluentSQLiteProvider())
		services.register(sqlite)
	}
    public override func configure(databases: inout DatabasesConfig) throws{
		databases.add(database: sqlite, as: .sqlite)
	}

    public override func configure(migrations: inout MigrationConfig){
		super.configure(migrations: &migrations)
		migrations.add(model: ExampleModel.self, database: .sqlite)
		migrations.add(model: ExampleSiblingModel.self, database: .sqlite)
		migrations.add(model: ExampleChildModel.self, database: .sqlite)
		migrations.add(model: ExampleModelSiblingPivot.self, database: .sqlite)
		migrations.add(migration: ExampleSeeder.self, database: .sqlite)
	}



	//MARK: Tests
	func testSeed() throws {
		XCTAssert(model: ExampleModel.self, hasCount: exampleModelCount, on: request)
		XCTAssert(model: ExampleSiblingModel.self, hasCount: exampleSiblingModelCount, on: request)
		XCTAssert(model: ExampleChildModel.self, hasCount: exampleChildModelCount, on: request)
	}

	func testSiblingsSeed() throws{
		let models = try ExampleModel.query(on: request).all().wait()
		try models.forEach { (model) in
			XCTAssertEqual(try model.siblings.query(on: request).count().wait(), siblingsPerExampleModel)
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
    public static func seeds() -> [SeedProtocol]{
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
