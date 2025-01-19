//
//  ModelFacotry.swift
//  FluentSeeder
//
//  Created by Brian Strobach on 6/27/18.
//

import Foundation
import Fluent
import Vapor
import Runtime
import RandomFactory
import RuntimeExtensions
import FluentExtensions


open class ModelFactory: RandomFactory {


    public func initializeModel<M: Model>(id: M.IDValue? = nil, on database: Database) async throws -> M {
        let model = try await self.randomized(type: M.self, on: database)
        model.id = id
        return model
    }

    open func randomized<M: Model>(type: M.Type = M.self, on database: Database) async throws -> M {
        let data = try await randomEncodedData(decodableTo: type, on: database)
        return try M.decode(fromJSON: data, using: self.config.jsonDecoder)
    }

    public func resolveRelationships<M: Model>(for type: M.Type, on database: Database) async throws -> [String: Any] {
        var values: [[String: Any]] = []
        for property in try properties(type) {
            if let generatable = property.type as? RandomGeneratable.Type,
               case let .asyncGenerator(generator) = generatable.strategy {
                let value = try await generator(database)
                values.append([self.config.codableKeyMapper(property.name): ["id": value]])
            }
        }
        guard !values.isEmpty else { return [:] }
        
        var allValues: [String: Any] = [:]
        for value in values {
            allValues = allValues.merging(value, uniquingKeysWith: { lhs, _ in lhs })
        }
        return allValues
    }

    open func randomEncodedData<M: Model>(decodableTo type: M.Type, on database: Database) async throws -> Data {
        var dict = try randomDictionary(decodableTo: type)
        let asyncDict = try await resolveRelationships(for: type, on: database)
        for (key, value) in asyncDict {
            dict[key] = value
        }
        
        return try dict.encodeAsJSONData(using: self.config.jsonEncoder)
    }
}

public extension RandomFactory.Config {
    func register<E: CaseIterable & RawRepresentable>(enumType: E.Type) {
        let name = try! Runtime.typeInfo(of: enumType).name
        enumFactory[name] = { E.allCases.randomElement()!.rawValue }
    }
}


public extension ModelFactory {
    static func fluentFactory() -> ModelFactory {
        let config = RandomFactory.Config()
        config.codableKeyMapper = { key in
            if key.starts(with: "_") {
                return String(key.dropFirst())
            }
            return key
        }
        config.overrides = { property in
            if let generatable = property.type as? RandomGeneratable.Type{
                switch generatable.strategy {
                case .skip, .asyncGenerator(_):
                    return RandomFactory.explicitNil
                case .factory(let valueType):
                    let factory = ModelFactory(config: config)
                    return try! factory.randomValue(ofType: valueType, for: property)
                case .custom(generator: let generator):
                    return generator()
                }
            }
            return nil //Let the default behavior generate a random value for this property
        }

        return ModelFactory(config: config)
    }
}

public enum GenerationStrategy {
    case skip
    case factory(_ generatedType: Any.Type)
    case custom(_ generator: () -> Any)
    case asyncGenerator(_ generator: (_ : Database) async throws -> Any)
}
public protocol RandomGeneratable {
    static var strategy: GenerationStrategy { get }
}


extension IDProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

extension FieldProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .factory(Value.self) }
}

extension OptionalFieldProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

extension EnumProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .factory(Value.self) }
}

extension OptionalEnumProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

//Special case, can't initialize these without a value. Later will be changed by
//Parent/Child see but maybe there is a better way to do this by passing in a
//database connection to this and sampling the existing parents.

extension ParentProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy {
        return .asyncGenerator({ database in
            guard let model = try await Value.query(on: database).random() else {
                fatalError("You must seed \(Value.self) before its dependents.")
            }
            let id = try model.requireID()
            
            if let uuid = id as? UUID {
                return uuid.uuidString
            }
            return id
            
        })
        //        return .factory(Value.self)
        //        return .custom {
        //            switch Value.IDValue.self {
        //            case is String.Type:
        //                return ["id" : "A"]
        //            case is Int.Type:
        //                return ["id" : 1]
        //            case is UUID.Type:
        //                return ["id" : UUID().uuidString]
        //            default:
        //                fatalError("Unhandled id type: \(Value.IDValue.self)")
        //            }
        //        }
    }
}

extension GroupProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .factory(Value.self) }
}


extension TimestampProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

extension OptionalParentProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy {
        return .custom({ 
            return ["id" : nil]
            // 50% chance of having an optional parent
//            guard Bool.random() else { return nil }
//            
//            guard let model = try await Value.query(on: database).random() else {
//                return nil
//            }
//            let id = try model.requireID()
//            
//            if let uuid = id as? UUID {
//                return uuid.uuidString
//            }
//            return id
        })
    }
}

extension ChildrenProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

extension OptionalChildProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}

extension SiblingsProperty: RandomGeneratable {
    public static var strategy: GenerationStrategy { .skip }
}
