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
            Seed<StudentModel>(count: studentModelCount, factory: factory),
            Seed<ClassModel>(count: classModelCount, factory: factory),
            Seed<ParentModel>(count: parentModelCount, factory: factory),
            Seed<ChildModel>(count: childModelCount, factory: factory),

//            //Then relationships that depend on those models existing
            SiblingSeed<ClassModel, StudentModel, EnrollmentModel>(count: classesPerStudent,
                                                                   through: \.$classes),
            ParentSeed<ParentModel, ChildModel>(at: \ChildModel.$parent)
        ]
    }
}
