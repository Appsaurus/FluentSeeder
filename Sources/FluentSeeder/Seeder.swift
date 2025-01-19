//
//  Seeder.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 6/28/18.
//

import Foundation
import Fluent

public protocol Seeder: AsyncMigration{
    func seeds(on database: Database) -> [SeedProtocol]
}
extension Seeder{

    public func prepare(on database: Database) async throws {
        try await seeds(on: database).asyncForEach { seed in
            try await seed.prepare(on: database)
        }
    }
    public func revert(on database: Database) async throws {
        try await seeds(on: database).asyncForEach { seed in
            try await seed.revert(on: database)
        }
    }

}


//public protocol Seeder: Migration{
//    func seeds(on database: Database) -> [EventLoopFuture<SeedProtocol>]
//}
//extension Seeder{
//
//    public func prepare(on database: Database) -> EventLoopFuture<Void> {
//        return seeds(on: database).compactMap { seeds in
//            return seeds.flatMap { $0.prepare(on: database) }
//        }.flatten(on: database).flattenVoid()
//    }
//
//    public func revert(on database: Database) -> EventLoopFuture<Void> {
//        return .done(on: database)
//    }
//}
