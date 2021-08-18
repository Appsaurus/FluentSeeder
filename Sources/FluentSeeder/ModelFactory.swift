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

public enum ModelFactory<M: Model>{
	case random
	case randomExcluding(keyPaths: [KeyPath<M, AnyQueryableProperty>])
	case randomWith(overrides: RandomValueGenerator)
	case randomFrom(factory: RandomFactory)
	case emptyInitialized
	case custom(initializer: () -> M)

	public func initializeModel(id: M.IDValue? = nil) throws -> M{
		var model: M!
		switch self{
		case .random:
			model = try RandomFactory.shared.randomized(type: M.self, overrides: { (property) -> Any? in
				if property.type == Optional<M.IDValue>.self{
					return RandomFactory.explicitNil
				}
				return nil //Let the default behavior generate a random value for this property
			})
		case .randomWith(let overrides):
			model = try RandomFactory.shared.randomized(type: M.self, overrides: overrides)
		case .randomExcluding(let keyPaths):
			model = try RandomFactory.shared.randomized(type: M.self, overrides: { (property) -> Any? in
//				guard !keyPaths.contains(where: {$0.propertyName == property.name}) else { return RandomFactory.explicitNil}
				return nil //Let the default behavior generate a random value for this property
			})
		case .randomFrom(let factory):
			model = try factory.randomized(type: M.self)
		case .emptyInitialized:
			if let initializableType = M.self as? EmptyInitializable.Type{
				model = initializableType.init() as! M
			}
			else{
				//TODO: Test this, pretty sure all tested models have implemented EmptyInitializable so far.
				model = try createInstance(of: M.self) as! M
			}
		case .custom(let initializer):
			model = initializer()
		}
		model.id = id
		return model
	}
}
