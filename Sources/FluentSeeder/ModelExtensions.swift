//
//  ModelExtensions.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 12/6/17.
//

import Foundation
import Fluent
import Vapor
import FluentExtensions

extension Model where Self: Decodable{

    @discardableResult
    static public func createSync(id: IDValue? = nil,
                                  factory: ModelFactory,
                                  on database: Database) throws -> Self{
        fatalError("Use async create instead of createSync")
    }

    @discardableResult
    static public func createBatchSync(size: Int,
                                       factory: ModelFactory,
                                       on database: Database) throws -> [Self]{
        fatalError("Use async createBatch instead of createBatchSync")
    }

    @discardableResult
    static public func create(id: IDValue? = nil,
                              factory: ModelFactory,
                              on database: Database) async throws -> Self{
        let model: Self = try await factory.initializeModel(id: id, on: database)
        return try await model.create(in: database)
    }

    @discardableResult
    static public func createBatch(size: Int,
                                   factory: ModelFactory,
                                   on database: Database) async throws -> [Self]{
        var models: [Self] = []
        if size > 0{
            for _ in 1...size{
                let model = try await self.create(factory: factory, on: database)
                models.append(model)
            }
        }
        return models
    }

    @discardableResult
    static public func findOrCreate(id: IDValue,
                                    factory: ModelFactory,
                                    on database: Database) async throws -> Self{
        if let existing = try await self.find(id, on: database) {
            return existing
        }
        return try await self.create(id: id, factory: factory, on: database)
    }

    @discardableResult
    static public func findOrCreateBatch(ids: [IDValue],
                                         factory: ModelFactory,
                                         on database: Database) async throws -> [Self]{
        var models: [Self] = []
        for id in ids{
            let model = try await self.findOrCreate(id: id, factory: factory, on: database)
            models.append(model)
        }
        return models
    }

    @discardableResult
    static public func findOrCreateSync(id: IDValue,
                                        factory: ModelFactory,
                                        on database: Database) throws -> Self{
        fatalError("Use async findOrCreate instead of findOrCreateSync")
    }

    @discardableResult
    static public func findOrCreateBatchSync(ids: [IDValue],
                                             factory: ModelFactory,
                                             on database: Database) throws -> [Self]{
        fatalError("Use async findOrCreateBatch instead of findOrCreateBatchSync")
    }
}

//TODO: Refactor this and other helpers into Vapor/Fluent extension libraries.
