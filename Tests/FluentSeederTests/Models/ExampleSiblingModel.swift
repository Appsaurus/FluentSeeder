//
//  ExampleSiblingModel.swift
//  Servasaurus
//
//  Created by Brian Strobach on 12/11/17.
//

import Fluent
import FluentSQLite
import Vapor

final class ExampleSiblingModel: FluentTestModel{

	public var id: Int?
	public var stringField: String = ""
	public var optionalStringField: String?
	public var intField: Int = 1
	public var doubleField: Double = 0.0
	public var booleanField: Bool = false
	public var dateField: Date = Date()

    public var siblings: Siblings<ExampleSiblingModel, ExampleModel, ExampleModelSiblingPivot> {
        return siblings()
    }
}
