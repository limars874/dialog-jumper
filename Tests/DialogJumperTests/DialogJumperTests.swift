import Testing
import Foundation
@testable import DialogJumper

@Test func bootstrapPackageHasExecutable() {
    #expect(AppMetadata.name == "dialog-jumper")
}

@Test func resolverAcceptsDirectoryString() throws {
    let directory = try makeFixtureDirectory()
    let resolved = ClipboardFolderResolver().resolve(rawString: directory.path)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverUsesFileParent() throws {
    let directory = try makeFixtureDirectory()
    let file = directory.appendingPathComponent("note.txt")
    try "fixture".write(to: file, atomically: true, encoding: .utf8)

    let resolved = ClipboardFolderResolver().resolve(rawString: file.path)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverAcceptsFileURLDirectory() throws {
    let directory = try makeFixtureDirectory()
    let resolved = ClipboardFolderResolver().resolve(rawString: directory.absoluteString)

    #expect(resolved == directory.standardizedFileURL)
}

@Test func resolverRejectsMissingPath() {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("dialog-jumper-tests")
        .appendingPathComponent(UUID().uuidString)

    #expect(ClipboardFolderResolver().resolve(rawString: missing.path) == nil)
}

@Test func resolverRejectsBlankAndPlainText() {
    let resolver = ClipboardFolderResolver()

    #expect(resolver.resolve(rawString: "  \n\t ") == nil)
    #expect(resolver.resolve(rawString: "copied words") == nil)
}

@Test func resolverExpandsHomeDirectory() {
    let resolved = ClipboardFolderResolver().resolve(rawString: "~")
    let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    #expect(resolved == home)
}

private func makeFixtureDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("dialog-jumper-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .standardizedFileURL

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
