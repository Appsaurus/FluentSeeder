//
//  Seeder.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 6/28/18.
//

import Foundation
import Fluent

public protocol Seeder: Migration{
	static func seeds() -> [SeedProtocol]
}
extension Seeder{
	public static func prepare(on conn: Database.Connection) -> EventLoopFuture<Void> {
		return seeds().map { (seed) -> Future<Void> in
			return seed.prepare(on: conn)
			}.flatten(on: conn)
	}

	public static func revert(on conn: Database.Connection) -> EventLoopFuture<Void> {
		return .done(on: conn)
	}
}
