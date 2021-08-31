import XCTest
import FluentTestModelsSeeder
import FluentSQLiteDriver
import FluentTestUtils

final class FluentSeederTests: FluentTestModels.SeededTestCase {
    override func configureTestModelDatabase(_ databases: Databases) {
        databases.use(.sqlite(.memory, connectionPoolTimeout: .minutes(2)), as: .sqlite)
    }    

	//MARK: Tests
	func testSeed() throws {
        XCTAssert(model: KitchenSink.self, hasCount: seeder.kitchenSinkModelCount, on: app.db)
        XCTAssert(model: TestStudentModel.self, hasCount: seeder.studentModelCount, on: app.db)
        XCTAssert(model: TestClassModel.self, hasCount: seeder.classModelCount, on: app.db)
        XCTAssert(model: TestParentModel.self, hasCount: seeder.parentModelCount, on: app.db)
        XCTAssert(model: TestChildModel.self, hasCount: seeder.childModelCount, on: app.db)
	}

	func testSiblingsSeed() throws{

        let models = try TestStudentModel.query(on: app.db).all().wait()
		try models.forEach { (model) in
            let classes = try model.$classes.query(on: app.db).all().wait()
            XCTAssertEqual(classes.count, seeder.classesPerStudent)
		}
	}

	func testParentSeed() throws{
        let children = try TestChildModel.query(on: app.db).all().wait()
		try children.forEach { (child) in
			XCTAssertNotNil(try child.$parent.query(on: app.db).first().wait())
		}
	}


    func testSort() throws {
        let keyPath = try KitchenSink.query(on: app.db).sort(\.$doubleField, .ascending).limit(5).all().wait()
        let string = try KitchenSink.query(on: app.db).sort("doubleField", .ascending).limit(5).all().wait()

        XCTAssertEqual(keyPath.values(at: \.doubleField), string.values(at: \.doubleField))
//        XCTAssertEqual(try keyPath[0].encodeAsJSONString(), try string[0].encodeAsJSONString())
//        XCTAssertEqual(try keyPath[1].encodeAsJSONString(), try string[1].encodeAsJSONString())
//        XCTAssertEqual(try keyPath[2].encodeAsJSONString(), try string[2].encodeAsJSONString())
//        XCTAssertEqual(try keyPath[3].encodeAsJSONString(), try string[3].encodeAsJSONString())
//        XCTAssertEqual(try keyPath[4].encodeAsJSONString(), try string[4].encodeAsJSONString())
    }
}
