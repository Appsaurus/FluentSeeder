//
//  FluentTestModelsSeeder.swift
//  
//
//  Created by Brian Strobach on 8/23/21.
//

import FluentTestModels

public class FluentTestModelsSeeder: Seeder{

    public var kitchenSinkModelCount = 5
    public var studentModelCount = 20
    public var classModelCount = 10
    public var classesPerStudent = 5
    public var parentModelCount = 5
    public var childModelCount = 10

    public init(){}

    public func seeds(on database: Database) -> [SeedProtocol] {
        let factory = ModelFactory.fluentFactory()
        factory.config.register(enumType: TestIntEnum.self)
        factory.config.register(enumType: TestStringEnum.self)
        factory.config.register(enumType: TestRawStringEnum.self)
        factory.config.register(enumType: TestRawIntEnum.self)
        return [
            //Seed models first
            Seed<KitchenSink>(count: kitchenSinkModelCount, factory: factory),
            Seed<TestStudentModel>(count: studentModelCount, factory: factory),
            Seed<TestClassModel>(count: classModelCount, factory: factory),
            Seed<TestParentModel>(count: parentModelCount, factory: factory),
            Seed<TestChildModel>(count: childModelCount, factory: factory),

//            //Then relationships that depend on those models existing
            SiblingSeed<TestClassModel, TestStudentModel, TestEnrollmentModel>(count: classesPerStudent,
                                                                   through: \.$classes),
            ParentSeed<TestParentModel, TestChildModel>(at: \TestChildModel.$parent)
        ]
    }
}
