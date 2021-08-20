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


    public func initializeModel<M: Model>(id: M.IDValue? = nil, on database: Database) throws -> Future<M> {
        try self.randomized(type: M.self, on: database).map { model in
            model.id = id
            return model
        }
    }

    open func randomized<M: Model>(type: M.Type = M.self, on database: Database) throws -> Future<M>{
        try randomEncodedData(decodableTo: type, on: database).flatMapThrowing { data in
            return try M.decode(fromJSON: data, using: self.config.jsonDecoder)
        }

    }

    public func resolveRelationships<M: Model>(for type: M.Type, on database: Database) throws -> Future<[String: Any]> {
        var futureValues: [Future<[String: Any]>] = []
        for property in try properties(type) {
            if let generatable = property.type as? RandomGeneratable.Type, case let .asyncGenerator(generator) = generatable.strategy {
                let futureValue = generator(database).map { value in
                    return [self.config.codableKeyMapper(property.name) : ["id" : value]] as [String: Any]
                }
                futureValues.append(futureValue)
            }
        }
        guard futureValues.count > 0 else { return database.eventLoop.future([:])}
        return futureValues.flatten(on: database).map { values in
            var allValues: [String: Any] = [:]
            for value in values {
                allValues = allValues.merging(value, uniquingKeysWith: {lhs, _ in return lhs })
            }
            return allValues
        }

    }

    open func randomEncodedData<M: Model>(decodableTo type: M.Type, on database: Database) throws -> Future<Data>{
        var dict = try randomDictionary(decodableTo: type)
        return try resolveRelationships(for: type, on: database).flatMapThrowing { asyncDict in
            for (key, value) in asyncDict {
                dict[key] = value
            }
            return try dict.encodeAsJSONData(using: self.config.jsonEncoder)
        }
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
    case asyncGenerator(_ generator: (_ : Database) -> Future<Any>)
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
            return Value.query(on: database).random().flatMapThrowing { model in
                guard let id = try model?.requireID() else {
                    fatalError("You must seed \(Value.self) before its dependents.")
                }
                if let uuid = id as? UUID {
                    return uuid.uuidString
                }
                return id
            }
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
    public static var strategy: GenerationStrategy { .skip }
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



