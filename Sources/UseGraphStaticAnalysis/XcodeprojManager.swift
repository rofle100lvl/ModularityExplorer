import Foundation
import XcodeProj

enum XcodeprojManager {
    static func getAllModules(projUrl: URL) throws -> [Module] {
        let proj = try XcodeProj(path: .init(projUrl.path()))
        return proj.pbxproj.nativeTargets
            .map {
                let moduleName = $0.name
                var moduleFiles = [URL]()

                let sourceBuildPhase = $0.buildPhases.filter {
                    $0 is PBXSourcesBuildPhase
                }.first

                if let sourceBuildPhase,
                   let files = sourceBuildPhase.files
                {
                    moduleFiles = files
                        .map {
                            do {
                                return try $0.file?.fullPath(sourceRoot: projUrl.deletingLastPathComponent().path())
                            } catch {
                                return nil
                            }
                        }
                        .compactMap { $0 }
                        .compactMap {
                            URL(fileURLWithPath: $0)
                        }
                }

                return Module(moduleName: moduleName, files: moduleFiles)
            }
    }
}
