//
//  Seeder.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 6/28/18.
//

import Foundation
import Fluent

public protocol Seeder: Migration{
	func seeds() -> [SeedProtocol]
}
extension Seeder{

	public func prepare(on database: Database) -> EventLoopFuture<Void> {        
		return seeds().map { seed in
			return seed.prepare(on: database)
        }.flatten(on: database.eventLoop)
	}

	public func revert(on database: Database) -> EventLoopFuture<Void> {
		return .done(on: database)
	}
}
