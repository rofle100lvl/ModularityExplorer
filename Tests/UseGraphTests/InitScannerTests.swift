import SwiftParser
import SwiftSyntax
@testable import UseGraphCore
import XCTest

final class InitScannerTests: XCTestCase {
    func test() async throws {
        let module = SourceModule(moduleName: "ModuleA", files: [
            File(name: "A.swift", source: structA),
            File(name: "A+B.swift", source: extensionA),
        ])
        let results = await InitScanner.processModules(modules: [module])
        XCTAssertEqual(results, [
            ModuleScanResult(fileScanResult: [
                "AExt0": Node(moduleName: "ModuleA", fileName: "A+B.swift", connectedTo: Set(["C"])),
                "A": UseGraphCore.Node(moduleName: "ModuleA", fileName: "A.swift", connectedTo: Set(["B", "AExt0"])),
            ], moduleName: "ModuleA"),
        ])
    }
}

extension InitScannerTests {
    var structA: String {
        """
        struct A {
        let a: B
        }
        """
    }

    var extensionA: String {
        """
        struct C {

        }

        extension A {
        var c: C { C() }
        }
        """
    }
}
