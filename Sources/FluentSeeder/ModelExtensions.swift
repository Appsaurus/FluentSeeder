//
//  VaporTestCase.swift
//  ServasaurusTests
//
//  Created by Brian Strobach on 12/6/17.
//

import Foundation
import Fluent
import Vapor
import FluentExtensions

extension Model where Self: Decodable{

	@discardableResult
	static public func createSync(id: IDValue? = nil, factory: ModelFactory<Self>, on database: Database) throws -> Self{
		return try create(id: id, factory: factory, on: database).wait()
	}

	@discardableResult
	static public func createBatchSync(size: Int, factory: ModelFactory<Self>, on database: Database) throws -> [Self]{
		return try createBatch(size: size, factory: factory, on: database).wait()
	}

	@discardableResult
	static public func create(id: IDValue? = nil, factory: ModelFactory<Self>, on database: Database) throws -> Future<Self>{
		let model: Self = try factory.initializeModel(id: id)
		return model.createAndReturn(on: database)
	}

	@discardableResult
	static public func createBatch(size: Int, factory: ModelFactory<Self>, on database: Database) throws -> Future<[Self]>{
        var models: [Future<Self>] = []
        if size > 0{
            for _ in 1...size{
                models.append(try self.create(factory: factory, on: database))
            }
        }
        return models.flatten(on: database)

	}

	@discardableResult
	static public func findOrCreate(id: IDValue, factory: ModelFactory<Self>,  on database: Database) throws -> Future<Self>{
		return self.find(id, on: database).unwrap(or: { () -> EventLoopFuture<Self> in
			return try! self.create(id: id, factory: factory, on: database)
		})

	}

	@discardableResult
	static public func findOrCreateBatch(ids: [IDValue], factory: ModelFactory<Self>, on database: Database) throws -> Future<[Self]>{
        var models: [Future<Self>] = []
        for id in ids{
            models.append(try self.findOrCreate(id: id, factory: factory, on: database))
        }
        return models.flatten(on: database)
	}

	@discardableResult
	static public func findOrCreateSync(id: IDValue, factory: ModelFactory<Self>, on database: Database) throws -> Self{
		let futureModel: Future<Self> = try findOrCreate(id: id, factory: factory, on: database)
		let model: Self = try futureModel.wait()
		return model
	}

	@discardableResult
	static public func findOrCreateBatchSync(ids: [IDValue], factory: ModelFactory<Self>, on database: Database) throws -> [Self]{
		return try findOrCreateBatch(ids: ids, factory: factory, on: database).wait()
	}
}

//TODO: Refactor this an other helpers into Vapor/Fluent extension libraries.
fileprivate extension Future where Value: Vapor.OptionalType {
	/// Unwraps an optional value contained inside a Future's expectation.
	/// If the optional resolves to `nil` (`.none`), the supplied error will be thrown instead.
    func unwrap(or resolve: @escaping () -> Future<Value.WrappedType>) -> Future<Value.WrappedType> {
		return flatMap { optional in
			guard let _ = optional.wrapped else {
				return resolve()
			}
			//TODO: Find a more elegant way to unwrap this since we should know that it exists due to first check. Might need to pass in connection as a parameter and map unwrapped value to future.
			return self.unwrap(or: Abort(.internalServerError))
		}
	}
}
