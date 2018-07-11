//
//  ExampleRelatedModel.swift
//  ServasaurusTests
//
//  Created by Brian Strobach on 12/1/17.
//

import Foundation
import Fluent
import FluentSQLite
import Vapor


final class ExampleChildModel: FluentTestModel{
	public var id: Int?
	public var stringField: String = ""
	public var optionalStringField: String?
	public var intField: Int = 1
	public var doubleField: Double = 0.0
	public var booleanField: Bool = false
	public var dateField: Date = Date()
	
    //MARK: Many-to-one relation example
    public var optionalParentModelId: ExampleModel.ID?
    public var optionalParentModel: Parent<ExampleChildModel, ExampleModel>?{
        return parent(\.optionalParentModelId)
    }

	public init() {}
}
