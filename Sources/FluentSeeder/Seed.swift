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
import FluentKit

public typealias Seedable = Model & Decodable

public protocol SeedProtocol{
	func prepare(on database: Database) -> Future<Void>
	func revert(on database: Database) -> Future<Void>
}

open class Seed<M: Seedable>: SeedProtocol {
	open var count: Int
	open var factory: ModelFactory
    public required init(count: Int = 100, factory: ModelFactory = .fluentFactory()) {
		self.count = count
		self.factory = factory
	}

	open func prepare(on database: Database) -> EventLoopFuture<Void> {
		return try! M.createBatch(size: count, factory: self.factory, on: database).transform(to: ())
	}

	open func revert(on database: Database) -> EventLoopFuture<Void> {
        return .done(on: database)
	}
}


extension Future where Value == Void {
    static func done(on database: Database) -> Future<Void> {
        database.eventLoop.makeSucceededFuture({}())
    }
}

extension Seed: Migration{

    public static var count: Int{
		return self<M>.init().count
	}
//
//	func prepare(on database: Database) -> EventLoopFuture<Void> {
//		return Self().prepare(on: database)
//	}
//
//	func revert(on database: Database) -> EventLoopFuture<Void> {
//		return Self().revert(on: database)
//	}

}

public enum SiblingSeedDirection{
	case rightToLeft //Attaches all models from the right query to each model in the left query
	case leftToRight //Attaches all models from the left query to each model in the right query
}
open class SiblingSeed<From: Model, To: Model, Through: Model>: SeedProtocol {


	open var count: Int
	open var fromQuery: QueryBuilder<From>?
	open var toQuery: QueryBuilder<To>?
    open var through: KeyPath<To, SiblingsProperty<To, From, Through>>

	public required init(count: Int = 5,
                         through: KeyPath<To, SiblingsProperty<To, From, Through>>,
                         fromQuery: QueryBuilder<From>? = nil,
                         toQuery: QueryBuilder<To>? = nil) {
		self.count = count
        self.through = through
		self.fromQuery = fromQuery
		self.toQuery = toQuery
	}

	open func prepare(on database: Database) -> EventLoopFuture<Void> {
        return Through.attachRandomSiblings(count: count, from: fromQuery, to: toQuery, through: through, on: database)
	}

	open func revert(on database: Database) -> EventLoopFuture<Void> {
		return .done(on: database)
	}
}

extension SiblingSeed: Migration{

//    public static var count: Int{
//		return Self().count
//	}
//	public typealias Database = M.Database
//	public static func prepare(on database: M.Database.Connection) -> EventLoopFuture<Void> {
//		return self<M>.init().prepare(on: database)
//	}
//
//	public static func revert(on database: M.Database.Connection) -> EventLoopFuture<Void> {
//		return self<M>.init().revert(on: database)
//	}

}

open class ChildSeed<Parent, Child>: SeedProtocol where Child: Model, Parent: Model{

	open var count: Int = 3
	open var parentQuery: QueryBuilder<Parent>?
	open var childQuery: QueryBuilder<Child>?
	open var keyPath: WritableKeyPath<Parent, ChildrenProperty<Parent, Child>>

	public init(count: Int,
				from childQuery: QueryBuilder<Child>? = nil,
				to parentQuery: QueryBuilder<Parent>? = nil,
				at keyPath: WritableKeyPath<Parent, ChildrenProperty<Parent, Child>>) {
		self.count = count
		self.parentQuery = parentQuery
		self.childQuery = childQuery
		self.keyPath = keyPath
	}

	open func prepare(on database: Database) -> EventLoopFuture<Void> {
			return Parent.attachRandomChildren(count: count,
											   from: childQuery,
											   to: parentQuery,
											   at: keyPath,
											   on: database)
	}

	open func revert(on database: Database) -> EventLoopFuture<Void> {
		return .done(on: database)
	}
}

public typealias ParentPropertyKeyPath<Child: Model, Parent: Model> = KeyPath<Child, ParentProperty<Child, Parent>>
public typealias OptionalParentPropertyKeyPath<Child: Model, Parent: Model> = KeyPath<Child, OptionalParentProperty<Child, Parent>>
public typealias ChildrenPropertyKeyPath<Parent: Model, Child: Model> = KeyPath<Parent, ChildrenProperty<Parent, Child>>
public typealias OptionalChildPropertyKeyPath<Parent: Model, Child: Model> = KeyPath<Parent, OptionalChildProperty<Parent, Child>>

open class ParentSeed<Parent, Child>: SeedProtocol where Child: Model, Parent: Model{

	open var parentQuery: QueryBuilder<Parent>?
	open var childQuery: QueryBuilder<Child>?
    open var keyPath: ParentPropertyKeyPath<Child, Parent>

	public init(from parentQuery: QueryBuilder<Parent>? = nil,
				to childQuery: QueryBuilder<Child>? = nil,
				at keyPath: ParentPropertyKeyPath<Child, Parent>) {
		self.parentQuery = parentQuery
		self.childQuery = childQuery
		self.keyPath = keyPath
	}


	open func prepare(on database: Database) -> EventLoopFuture<Void> {
		return Child.attachRandomParent(from: parentQuery,
										to: childQuery,
										at: keyPath,
										on: database)
	}

	open func revert(on database: Database) -> EventLoopFuture<Void> {
		return .done(on: database)
	}
}

extension QueryBuilder{

	/// Perform async operations on every result of a query.
	///
	/// - Parameters:
	///   - conn: The Database to perform they query on.
	///   - iteration: Logic to perform on each result.
	/// - Returns: A void future when all iterations have been completed.
	public func iterateVoid(on database: Database, _ iteration: @escaping (Model) -> Future<Void>) -> Future<Void>{
		return iterate(on: database, iteration).transform(to: ())
	}

	public func iterate<T>(on database: Database, _ iteration: @escaping (Model) -> Future<T>) -> Future<[T]>{
		let models = all()
		return models.flatMap { models in
			var futureVoids: [Future<T>] = []
			models.forEach({ (model) in
				futureVoids.append(iteration(model))
			})
			return futureVoids.flatten(on: database)
		}
	}
}

public extension Model {
    static func attachRandomParent<P: Model>(from parentQuery: QueryBuilder<P>? = nil,
                                             to childQuery: QueryBuilder<Self>? = nil,
                                             at keyPath: ParentPropertyKeyPath<Self, P>,
                                             on database: Database) -> Future<Void>{
        let childQuery = childQuery ?? query(on: database)
        return childQuery.iterate(on: database) { (child) -> EventLoopFuture<Void> in
            let futureParent = parentQuery?.random() ?? P.random(on: database)
            return futureParent.unwrap(or: Abort(.internalServerError)).flatMap { parent in
                //Guaranteed since we are querying
                if let id = parent.id {
                    child[keyPath: keyPath].id = id
                }
                return child.save(on: database)
            }
        }.flattenVoid()
    }

    static func attachRandomChildren<C: Model>(count: Int,
													  from childQuery: QueryBuilder<C>? = nil,
													  to parentQuery: QueryBuilder<Self>? = nil,
													  at keyPath: ChildrenPropertyKeyPath<Self, C>,
													  on database: Database) -> Future<Void>{
		let parentQuery = parentQuery ?? query(on: database)
        return parentQuery.iterate(on: database) { (model: Self) -> Future<Void> in
			let futureChildren = childQuery?.randomSlice(count: count) ?? C.random(on: database, count: count)
			return futureChildren.flatMap { children in
                model[keyPath: keyPath].create(children, on: database)
			}
		}.flattenVoid()
	}

    static func attachAllChildren<C: Model>(count: Int,
                                            from childQuery: QueryBuilder<C>? = nil,
                                            to parentQuery: QueryBuilder<Self>? = nil,
                                            at keyPath: ChildrenPropertyKeyPath<Self, C>,
                                            on database: Database) -> Future<Void>{
        let parentQuery = parentQuery ?? query(on: database)
        return parentQuery.iterate(on: database) { (model: Self) -> Future<Void> in
            let futureChildren = childQuery?.all() ?? C.query(on: database).all()
            return futureChildren.flatMap { children in
                model[keyPath: keyPath].create(children, on: database)
            }
        }.flattenVoid()
    }
}

extension Model {
    public static func attachRandomSiblings<From: Model, To: Model>(count: Int,
                                                                            from fromQuery: QueryBuilder<From>? = nil,
                                                                            to toQuery: QueryBuilder<To>? = nil,
                                                                            through: KeyPath<To, SiblingsProperty<To, From, Self>>,
                                                                            on database: Database) -> Future<Void> {
        let toQuery = toQuery ?? To.query(on: database)
        return toQuery.iterate(on: database, { (model) -> Future<Void> in
            let modelsToAttach = fromQuery?.randomSlice(count: count) ?? From.random(on: database, count: count)
            return modelsToAttach.flatMap{ modelsToAttach in
                return model[keyPath: through].attach(modelsToAttach, on: database)
            }
        }).flattenVoid()
	}

//	public static func attachRandomSiblings<From: Model, To: Model, Through: Model>(count: Int,
//										   from leftQuery: QueryBuilder<From>? = nil,
//										   to rightQuery: QueryBuilder<Database, Right>? = nil,
//										   on database: Database) -> Future<Void>{
//		let rightQuery = rightQuery ?? Right.query(on: database)
//		return rightQuery.iterate(on: database, { (model) -> EventLoopFuture<[Self]> in
//			let modelsToAttach = leftQuery?.random(count: count) ?? Left.random(on: database, count: count)
//			return modelsToAttach.flatMap({ modelsToAttach -> EventLoopFuture<[Self]> in
//				let siblings: Siblings<Right, Left, Self> = model.siblings()
//				return siblings.attach(modelsToAttach, on: database)
//			})
//		}).flattenVoid()
//	}
}
