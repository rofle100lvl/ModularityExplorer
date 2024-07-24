import SwiftParser
import SwiftSyntax
@testable import UseGraphCore
import XCTest

final class OwnershipFinderClosureTests: XCTestCase {
    func testClassWithVariableInside() throws {
        let rootNode: SourceFileSyntax = Parser.parse(source: classWithVariableInside)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        XCTAssertEqual(visitor.graphDependencies, ["A": Set(["SomeClass"])])
    }

    func testClassWithFunction() throws {
        let rootNode: SourceFileSyntax = Parser.parse(source: classWithFunction)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        XCTAssertEqual(visitor.graphDependencies, ["A": Set(["SomeClass"])])
    }

    func testClassWithInnerStruct() throws {
        let rootNode: SourceFileSyntax = Parser.parse(source: classWithInnerStruct)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        XCTAssertEqual(visitor.graphDependencies, ["B": Set(["SomeClass"]), "A": Set(["B"])])
    }

    func testTwoClassesWithConnectionBetweenThem() throws {
        let rootNode: SourceFileSyntax = Parser.parse(source: twoClassesWithConnectionBetweenThem)
        let visitor = DefinitionVisitor()
        visitor.walk(rootNode)
        XCTAssertEqual(visitor.graphDependencies, ["B": Set(["SomeClass"]), "A": Set(["B"])])
    }
}

extension OwnershipFinderClosureTests {
    var classWithVariableInside: String {
        """
        class A {
            let a: SomeClass = 5
        }
        """
    }

    var classWithFunction: String {
        """
        class A {
            func someFunc() -> SomeClass {
                SomeClass()
            }
        }
        """
    }

    var classWithInnerStruct: String {
        """
        class A {
            struct B {
                let someClass: SomeClass
            }
        }
        """
    }

    var twoClassesWithConnectionBetweenThem: String {
        """
        struct B {
            let someClass: SomeClass
        }

        class A {
            let b: B
        }
        """
    }
}
