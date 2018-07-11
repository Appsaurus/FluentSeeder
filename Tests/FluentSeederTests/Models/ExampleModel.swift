//
//  Model.swift
//  App
//
//  Created by Brian Strobach on 11/28/17.
//

import Foundation
import Fluent
import FluentSQLite
import Vapor
import FluentTestUtils

final class ExampleModel: FluentTestModel{

	public var id: Int?
	public var stringField: String = ""
	public var optionalStringField: String?
	public var intField: Int = 1
	public var optionalIntField: Int?
	public var doubleField: Double = 0.0
	public var booleanField: Bool = false
	public var dateField: Date = Date()

	//MARK: One-to-many relation example
	public var childModels: Children<ExampleModel, ExampleChildModel>{
		return children(\.optionalParentModelId)
	}

	public var siblings: Siblings<ExampleModel, ExampleSiblingModel, ExampleModelSiblingPivot> {
		return siblings()
	}
}


final class ExampleModelSiblingPivot:  SQLitePivot, ModifiablePivot, Migration{
	public var id: Int?
	var exampleModelID: ExampleModel.ID
	var siblingID: ExampleSiblingModel.ID


	public typealias Left = ExampleModel
	public typealias Right = ExampleSiblingModel
	public static let leftIDKey: LeftIDKey = \ExampleModelSiblingPivot.exampleModelID
	public static let rightIDKey: RightIDKey = \ExampleModelSiblingPivot.siblingID
	public init(_ left: ExampleModelSiblingPivot.Left, _ right: ExampleModelSiblingPivot.Right) throws {
		exampleModelID = left.id!
		siblingID = right.id!
	}

	public init(_ exampleModelID: ExampleModel.ID, _ siblingID: ExampleSiblingModel.ID) {
		self.exampleModelID = exampleModelID
		self.siblingID = siblingID
	}
}

