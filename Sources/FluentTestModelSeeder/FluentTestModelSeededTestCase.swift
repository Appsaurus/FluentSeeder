//
//  FluentTestModelSeededTestCase.swift
//  
//
//  Created by Brian Strobach on 8/23/21.
//

import FluentTestModels
extension FluentTestModels {
    open class SeededTestCase: FluentTestModels.TestCase {

        open var seeder = FluentTestModelSeeder()
        open var autoSeed: Bool {
            return true
        }
        override public func migrate(_ migrations: Migrations) throws {
            try super.migrate(migrations)
            if autoSeed {
                migrations.add(seeder)
            }
        }

    }
}
