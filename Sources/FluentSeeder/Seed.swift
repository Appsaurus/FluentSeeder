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
    func prepare(on database: Database) async throws -> Void
    func revert(on database: Database) async throws -> Void
}

open class Seed<M: Seedable>: SeedProtocol, @unchecked Sendable {
    open var count: Int
    open var factory: ModelFactory
    public required init(count: Int = 100, factory: ModelFactory = .fluentFactory()) {
        self.count = count
        self.factory = factory
    }

    open func prepare(on database: Database) async throws -> Void {
        try await M.createBatch(size: count, factory: self.factory, on: database)
    }

    open func revert(on database: Database) async throws -> Void {
        // No-op
    }
}


extension Seed: AsyncMigration{

    public static var count: Int{
        return Seed<M>.init().count
    }
//
//    func prepare(on database: Database) async throws -> Void {
//        try await Self().prepare(on: database)
//    }
//
//    func revert(on database: Database) async throws -> Void {
//        try await Self().revert(on: database)
//    }

}

public enum SiblingSeedDirection: @unchecked Sendable {
    case rightToLeft //Attaches all models from the right query to each model in the left query
    case leftToRight //Attaches all models from the left query to each model in the right query
}
open class SiblingSeed<From: Model, To: Model, Through: Model>: SeedProtocol, @unchecked Sendable {


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

    open func prepare(on database: Database) async throws -> Void {
        try await Through.attachRandomSiblings(count: count, from: fromQuery, to: toQuery, through: through, on: database)
    }

    open func revert(on database: Database) async throws -> Void {
        // No-op
    }
}

extension SiblingSeed: AsyncMigration{

//    public static var count: Int{
//        return self.init().count
//    }
//    public typealias Database = M.Database
//    public static func prepare(on database: M.Database.Connection) async throws -> Void {
//        try await self<M>.init().prepare(on: database)
//    }
//
//    public static func revert(on database: M.Database.Connection) async throws -> Void {
//        try await self<M>.init().revert(on: database)
//    }

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

    open func prepare(on database: Database) async throws -> Void {
            try await Parent.attachRandomChildren(count: count,
                                               from: childQuery,
                                               to: parentQuery,
                                               at: keyPath,
                                               on: database)
    }

    open func revert(on database: Database) async throws -> Void {
        // No-op
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


    open func prepare(on database: Database) async throws -> Void {
        try await Child.attachRandomParent(from: parentQuery,
                                        to: childQuery,
                                        at: keyPath,
                                        on: database)
    }

    open func revert(on database: Database) async throws -> Void {
        // No-op
    }
}

extension QueryBuilder{

    /// Perform async operations on every result of a query.
    ///
    /// - Parameters:
    ///   - conn: The Database to perform they query on.
    ///   - iteration: Logic to perform on each result.
    /// - Returns: A void future when all iterations have been completed.
    public func iterateAsync<T>(on database: Database, _ iteration: @escaping (Model) async throws -> T) async throws -> [T] {
        let models = try await all()
        var results: [T] = []
        for model in models {
            let result = try await iteration(model)
            results.append(result)
        }
        return results
    }

    public func iterateVoid(on database: Database, _ iteration: @escaping (Model) async throws -> Void) async throws -> Void {
        let models = try await all()
        for model in models {
            try await iteration(model)
        }
    }
}

public extension Model {
    static func attachRandomParent<P: Model>(from parentQuery: QueryBuilder<P>? = nil,
                                             to childQuery: QueryBuilder<Self>? = nil,
                                             at keyPath: ParentPropertyKeyPath<Self, P>,
                                             on database: Database) async throws -> Void {
        let childQuery = childQuery ?? query(on: database)
        let children = try await childQuery.all()
        
        try await children.asyncForEach { child in
            var parent = try await parentQuery?.random()
            if parent == nil {
                parent = try await P.random(on: database)
            }
            guard let id = parent?.id else {
                throw Abort(.internalServerError)
            }
            child[keyPath: keyPath].id = id
            try await child.save(on: database)
        }
    }

    static func attachRandomChildren<C: Model>(count: Int,
                                                      from childQuery: QueryBuilder<C>? = nil,
                                                      to parentQuery: QueryBuilder<Self>? = nil,
                                                      at keyPath: ChildrenPropertyKeyPath<Self, C>,
                                                      on database: Database) async throws -> Void {
        let parentQuery = parentQuery ?? query(on: database)
        let parents = try await parentQuery.all()
        
        try await parents.asyncForEach { parent in
            var children = try await childQuery?.randomSlice(count: count)
            if children == nil {
                children = try await C.random(on: database, count: count)
            }
            guard let children else {
                return
            }
            try await parent[keyPath: keyPath].create(children, on: database)
        }
    }

    static func attachAllChildren<C: Model>(count: Int,
                                            from childQuery: QueryBuilder<C>? = nil,
                                            to parentQuery: QueryBuilder<Self>? = nil,
                                            at keyPath: ChildrenPropertyKeyPath<Self, C>,
                                            on database: Database) async throws -> Void {
        let parentQuery = parentQuery ?? query(on: database)
        let parents = try await parentQuery.all()
        
        try await parents.asyncForEach { parent in
            var children = try await childQuery?.all()
            if children == nil {
                children = try await C.query(on: database).all()
            }
            guard let children else {
                return
            }
            try await parent[keyPath: keyPath].create(children, on: database)
        }
            
    }

    static func attachRandomSiblings<From: Model, To: Model>(count: Int,
                                                                            from fromQuery: QueryBuilder<From>? = nil,
                                                                            to toQuery: QueryBuilder<To>? = nil,
                                                                            through: KeyPath<To, SiblingsProperty<To, From, Self>>,
                                                                            on database: Database) async throws -> Void {
        let toQuery = toQuery ?? To.query(on: database)
        let models = try await toQuery.all()
        
        try await models.asyncForEach { model in
            var modelsToAttach = try await fromQuery?.randomSlice(count: count)
            if modelsToAttach == nil {
                modelsToAttach = try await From.random(on: database, count: count)
            }
            guard let modelsToAttach else {
                return
            }
            try await model[keyPath: through].attach(modelsToAttach, on: database)
        }
    }

//    public static func attachRandomSiblings<From: Model, To: Model, Through: Model>(count: Int,
//                                           from leftQuery: QueryBuilder<From>? = nil,
//                                           to rightQuery: QueryBuilder<Database, Right>? = nil,
//                                           on database: Database) async throws -> Void{
//        let rightQuery = rightQuery ?? Right.query(on: database)
//        let models = try await rightQuery.all()
//
//        for model in models {
//            let modelsToAttach = try await (leftQuery?.random(count: count) ?? Left.random(on: database, count: count))
//            let siblings: Siblings<Right, Left, Self> = model.siblings()
//            try await siblings.attach(modelsToAttach, on: database)
//        }
//    }
}
