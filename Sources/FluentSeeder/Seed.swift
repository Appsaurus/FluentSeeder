//
//  Seed.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 6/27/18.
//

import Foundation
import Fluent
import Runtime
import RandomFactory
import RuntimeExtensions
import Fakery
import FluentExtensions
import Vapor

public typealias Seedable = Model & Decodable

public protocol SeedProtocol{
	func prepare(on conn: DatabaseConnectable) -> Future<Void>
	func revert(on conn: DatabaseConnectable) -> Future<Void>
}

open class Seed<M: Seedable>: SeedProtocol where M.Database: MigrationSupporting{
	open var count: Int
	open var factory: ModelFactory<M> = .random
	public required init(count: Int = 100, factory: ModelFactory<M> = .random) {
		self.count = count
		self.factory = factory
	}

	open func prepare(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return try! M.createBatch(size: count, factory: self.factory, on: conn).transform(to: ())
	}

	open func revert(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return .done(on: conn)
	}
}

extension Seed: Migration{

    public static var count: Int{
		return self<M>.init().count
	}
	public typealias Database = M.Database
	public static func prepare(on conn: M.Database.Connection) -> EventLoopFuture<Void> {
		return self<M>.init().prepare(on: conn)
	}

	public static func revert(on conn: M.Database.Connection) -> EventLoopFuture<Void> {
		return self<M>.init().revert(on: conn)
	}

}

public enum SiblingSeedDirection{
	case rightToLeft //Attaches all models from the right query to each model in the left query
	case leftToRight //Attaches all models from the left query to each model in the right query
}
open class SiblingSeed<M: ModifiablePivot & Migration>: SeedProtocol
where M.Database: JoinSupporting, M.Database == M.Left.Database, M.Database == M.Right.Database{


	open var count: Int
	open var leftQuery: QueryBuilder<M.Left.Database, M.Left>?
	open var rightQuery: QueryBuilder<M.Right.Database, M.Right>?
	open var direction: SiblingSeedDirection
	public required init(count: Int = 5, leftQuery: QueryBuilder<M.Left.Database, M.Left>? = nil, rightQuery: QueryBuilder<M.Right.Database, M.Right>? = nil, direction: SiblingSeedDirection = .rightToLeft) {
		self.count = count
		self.leftQuery = leftQuery
		self.rightQuery = rightQuery
		self.direction = direction
	}

	open func prepare(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		switch direction{
		case .leftToRight:
			return M.attachRandomSiblings(count: count, from: leftQuery, to: rightQuery, on: conn)
		case .rightToLeft:
			return M.attachRandomSiblings(count: count, from: rightQuery, to: leftQuery, on: conn)
		}
	}

	open func revert(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return .done(on: conn)
	}
}

extension SiblingSeed: Migration{

    public static var count: Int{
		return self<M>.init().count
	}
	public typealias Database = M.Database
	public static func prepare(on conn: M.Database.Connection) -> EventLoopFuture<Void> {
		return self<M>.init().prepare(on: conn)
	}

	public static func revert(on conn: M.Database.Connection) -> EventLoopFuture<Void> {
		return self<M>.init().revert(on: conn)
	}

}

open class ChildSeed<Parent, Child>: SeedProtocol where Child: Model, Parent: Model{

	open var count: Int = 3
	open var parentQuery: QueryBuilder<Parent.Database, Parent>?
	open var childQuery: QueryBuilder<Child.Database, Child>?
	open var keyPath: WritableKeyPath<Child, Parent.ID?>

	public init(count: Int,
				from childQuery: QueryBuilder<Child.Database, Child>? = nil,
				to parentQuery: QueryBuilder<Parent.Database, Parent>? = nil,
				at keyPath: WritableKeyPath<Child, Parent.ID?>) {
		self.count = count
		self.parentQuery = parentQuery
		self.childQuery = childQuery
		self.keyPath = keyPath
	}

	open func prepare(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
			return Parent.attachRandomChildren(count: count,
											   from: childQuery,
											   to: parentQuery,
											   at: keyPath,
											   on: conn)
	}

	open func revert(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return .done(on: conn)
	}
}

open class ParentSeed<Parent, Child>: SeedProtocol where Child: Model, Parent: Model{

	open var parentQuery: QueryBuilder<Parent.Database, Parent>?
	open var childQuery: QueryBuilder<Child.Database, Child>?
	open var keyPath: WritableKeyPath<Child, Parent.ID?>

	public init(from parentQuery: QueryBuilder<Parent.Database, Parent>? = nil,
				to childQuery: QueryBuilder<Child.Database, Child>? = nil,
				at keyPath: WritableKeyPath<Child, Parent.ID?>) {
		self.parentQuery = parentQuery
		self.childQuery = childQuery
		self.keyPath = keyPath
	}


	open func prepare(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return Child.attachRandomParent(from: parentQuery,
										to: childQuery,
										at: keyPath,
										on: conn)
	}

	open func revert(on conn: DatabaseConnectable) -> EventLoopFuture<Void> {
		return .done(on: conn)
	}
}

extension QueryBuilder{

	/// Perform async operations on every result of a query.
	///
	/// - Parameters:
	///   - conn: The DatabaseConnectable to perform they query on.
	///   - iteration: Logic to perform on each result.
	/// - Returns: A void future when all iterations have been completed.
	public func iterateVoid(on conn: DatabaseConnectable, _ iteration: @escaping (Result) -> Future<Void>) -> Future<Void>{
		return iterate(on: conn, iteration).transform(to: ())
	}

	public func iterate<T>(on conn: DatabaseConnectable, _ iteration: @escaping (Result) -> Future<T>) -> Future<[T]>{
		let models = all()
		return models.flatMap(to: [T].self) { models in
			var futureVoids: [Future<T>] = []
			models.forEach({ (model) in
				futureVoids.append(iteration(model))
			})
			return futureVoids.flatten(on: conn)
		}
	}
}

extension Model {
	public static func attachRandomParent<P: Model>(from parentQuery: QueryBuilder<P.Database, P>? = nil,
													to childQuery: QueryBuilder<Database, Self>? = nil,
													at keyPath: WritableKeyPath<Self, P.ID?>,
													on conn: DatabaseConnectable) -> Future<Void>{
		let childQuery = childQuery ?? query(on: conn)
		return childQuery.iterate(on: conn) { (child) -> EventLoopFuture<Self> in
			let futureParent = parentQuery?.random() ?? P.random(on: conn)
			return futureParent.unwrap(or: Abort(.internalServerError)).flatMap({ parent -> EventLoopFuture<Self> in
				var child = child
				child[keyPath: keyPath] = parent.fluentID
				return child.save(on: conn)
			})
			}.flattenVoid()
	}

	public static func attachRandomChildren<C: Model>(count: Int,
													  from childQuery: QueryBuilder<C.Database, C>? = nil,
													  to parentQuery: QueryBuilder<Database, Self>? = nil,
													  at keyPath: WritableKeyPath<C, ID?>,
													  on conn: DatabaseConnectable) -> Future<Void>{
		let parentQuery = parentQuery ?? query(on: conn)
		return parentQuery.iterate(on: conn) { (model) -> EventLoopFuture<[C]> in
			let futureChildren = childQuery?.random(count: count) ?? C.random(on: conn, count: count)
			return futureChildren.flatMap({ children -> EventLoopFuture<[C]> in
				children.forEach({ (child) in
					var child = child
					child[keyPath: keyPath] = model.fluentID
				})
				return children.save(on: conn)
			})
		}.flattenVoid()
	}

	public static func attachAllChildren<C: Model>(from childQuery: QueryBuilder<C.Database, C>? = nil,
												   to parentQuery: QueryBuilder<Database, Self>? = nil,
												   at keyPath: WritableKeyPath<C, ID?>,
												   on conn: DatabaseConnectable) -> Future<Void>{
		let parentQuery = parentQuery ?? query(on: conn)
		return parentQuery.iterate(on: conn) { (model) -> EventLoopFuture<[C]> in
			let futureChildren = childQuery?.all() ?? C.query(on: conn).all()
			return futureChildren.flatMap({ children -> EventLoopFuture<[C]> in
				children.forEach({ (child) in
					var child = child
					child[keyPath: keyPath] = model.fluentID
				})
				return children.save(on: conn)
			})
		}.flattenVoid()
	}
}

extension ModifiablePivot where Self: Migration, Database: JoinSupporting, Database == Left.Database, Database == Right.Database {
	public static func attachRandomSiblings(count: Int,
										   from rightQuery: QueryBuilder<Database, Right>? = nil,
										   to leftQuery: QueryBuilder<Database, Left>? = nil,
										   on conn: DatabaseConnectable) -> Future<Void>{
		let leftQuery = leftQuery ?? Left.query(on: conn)
		return leftQuery.iterate(on: conn, { (model) -> EventLoopFuture<[Self]> in
			let modelsToAttach = rightQuery?.random(count: count) ?? Right.random(on: conn, count: count)
			return modelsToAttach.flatMap({ modelsToAttach -> EventLoopFuture<[Self]> in
				let siblings: Siblings<Left, Right, Self> = model.siblings()
				return siblings.attach(modelsToAttach, on: conn)
			})
		}).flattenVoid()
	}

	public static func attachRandomSiblings(count: Int,
										   from leftQuery: QueryBuilder<Database, Left>? = nil,
										   to rightQuery: QueryBuilder<Database, Right>? = nil,
										   on conn: DatabaseConnectable) -> Future<Void>{
		let rightQuery = rightQuery ?? Right.query(on: conn)
		return rightQuery.iterate(on: conn, { (model) -> EventLoopFuture<[Self]> in
			let modelsToAttach = leftQuery?.random(count: count) ?? Left.random(on: conn, count: count)
			return modelsToAttach.flatMap({ modelsToAttach -> EventLoopFuture<[Self]> in
				let siblings: Siblings<Right, Left, Self> = model.siblings()
				return siblings.attach(modelsToAttach, on: conn)
			})
		}).flattenVoid()
	}
}
