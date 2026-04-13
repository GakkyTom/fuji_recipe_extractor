import Foundation

actor RecipeScanner {
    private let exifToolPath = "/usr/local/bin/exiftool"

    func scan(configuration: ScanConfiguration, logger: @escaping (String) async -> Void) async throws -> ScanResult {
        let inputDirectory = configuration.inputDirectory

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputDirectory.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AppError.invalidInputDirectory(inputDirectory.path(percentEncoded: false))
        }

        let exifURL = URL(fileURLWithPath: exifToolPath)
        guard FileManager.default.isExecutableFile(atPath: exifURL.path(percentEncoded: false)) else {
            throw AppError.exifToolMissing(exifToolPath)
        }

        let files = jpegFiles(in: inputDirectory)
        if files.isEmpty {
            return ScanResult(
                photos: [],
                summary: "No JPEG files found in \(inputDirectory.path(percentEncoded: false))"
            )
        }

        if configuration.verbose {
            await logger("[verbose] Found \(files.count) JPEG files")
        }

        let records = try await runExifTool(on: files, verbose: configuration.verbose, logger: logger)
        let photos = records.map(buildPhotoRecipe(from:))
        try await writeOutput(photos: photos, configuration: configuration, logger: logger)

        let prefix = configuration.dryRun ? "Dry run completed" : "Scan completed"
        return ScanResult(
            photos: photos,
            summary: "\(prefix): \(photos.count) file(s) processed"
        )
    }

    private func jpegFiles(in directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var urls: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            let ext = item.pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" {
                urls.append(item)
            }
        }

        return urls.sorted { $0.path(percentEncoded: false).lowercased() < $1.path(percentEncoded: false).lowercased() }
    }

    private func runExifTool(on files: [URL], verbose: Bool, logger: @escaping (String) async -> Void) async throws -> [ExifToolRecord] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exifToolPath)
        process.arguments = [
            "-j",
            "-FilmMode",
            "-DynamicRange",
            "-DevelopmentDynamicRange",
            "-HighlightTone",
            "-ShadowTone",
            "-Saturation",
            "-NoiseReduction",
            "-Sharpness",
            "-Clarity",
            "-GrainEffectRoughness",
            "-GrainEffectSize",
            "-ColorChromeEffect",
            "-ColorChromeFXBlue",
            "-WhiteBalance",
            "-WhiteBalanceFineTune",
            "-ISO",
            "-ExposureCompensation"
        ] + files.map { $0.path(percentEncoded: false) }

        if verbose {
            await logger("[verbose] Running: \(([exifToolPath] + (process.arguments ?? [])).joined(separator: " "))")
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw AppError.processFailed("failed to run exiftool: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw AppError.processFailed("exiftool failed with exit code \(process.terminationStatus)\n\(output)\n\(errorOutput)")
        }

        do {
            return try JSONDecoder().decode([ExifToolRecord].self, from: outputData)
        } catch {
            throw AppError.invalidExifJSON("failed to parse exiftool JSON output: \(error.localizedDescription)")
        }
    }

    private func writeOutput(
        photos: [PhotoRecipe],
        configuration: ScanConfiguration,
        logger: @escaping (String) async -> Void
    ) async throws {
        let outputDirectory = configuration.outputDirectory
        let notesDirectory = outputDirectory.appending(path: "notes", directoryHint: .isDirectory)
        let imagesDirectory = outputDirectory.appending(path: "images", directoryHint: .isDirectory)
        let recipesDirectory = outputDirectory.appending(path: "recipes", directoryHint: .isDirectory)
        let indexesDirectory = outputDirectory.appending(path: "indexes", directoryHint: .isDirectory)

        if !configuration.dryRun {
            for directory in [outputDirectory, notesDirectory, imagesDirectory, recipesDirectory, indexesDirectory] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        }

        for photo in photos {
            let sourceURL = URL(fileURLWithPath: photo.sourcePath)
            let noteURL = notesDirectory.appending(path: "\(photo.title).md")
            let imageURL = imagesDirectory.appending(path: photo.sourceFileName)

            try await writeText(renderPhotoMarkdown(photo), to: noteURL, dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)
            try await copyItem(from: sourceURL, to: imageURL, dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)

            switch configuration.copyMode {
            case .none:
                break
            case .recipe:
                let target = recipesDirectory.appending(path: photo.recipeKey, directoryHint: .isDirectory).appending(path: photo.sourceFileName)
                try await copyItem(from: sourceURL, to: target, dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)
            case .film:
                let target = recipesDirectory.appending(path: photo.filmKey, directoryHint: .isDirectory).appending(path: photo.sourceFileName)
                try await copyItem(from: sourceURL, to: target, dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)
            }
        }

        try await writeText(renderFilmIndex(photos), to: indexesDirectory.appending(path: "film.md"), dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)
        try await writeText(renderRecipeIndex(photos), to: indexesDirectory.appending(path: "recipes.md"), dryRun: configuration.dryRun, verbose: configuration.verbose, logger: logger)
    }

    private func writeText(
        _ text: String,
        to url: URL,
        dryRun: Bool,
        verbose: Bool,
        logger: @escaping (String) async -> Void
    ) async throws {
        if dryRun {
            if verbose {
                await logger("[verbose] [dry-run] write \(url.path(percentEncoded: false))")
            }
            return
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try text.write(to: url, atomically: true, encoding: .utf8)
        if verbose {
            await logger("[verbose] Wrote \(url.path(percentEncoded: false))")
        }
    }

    private func copyItem(
        from source: URL,
        to target: URL,
        dryRun: Bool,
        verbose: Bool,
        logger: @escaping (String) async -> Void
    ) async throws {
        if dryRun {
            if verbose {
                await logger("[verbose] [dry-run] copy \(source.path(percentEncoded: false)) -> \(target.path(percentEncoded: false))")
            }
            return
        }

        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if FileManager.default.fileExists(atPath: target.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: source, to: target)
        if verbose {
            await logger("[verbose] Copied \(source.lastPathComponent) -> \(target.path(percentEncoded: false))")
        }
    }

    private func renderPhotoMarkdown(_ photo: PhotoRecipe) -> String {
        [
            "---",
            "film: \(photo.film)",
            "dr: \(photo.dynamicRange)",
            "---",
            "",
            "# \(photo.title)",
            "",
            "![[\(photo.sourceFileName)]]",
            "",
            "- Film Simulation: \(photo.film)",
            "- Dynamic Range: \(photo.dynamicRange)",
            "- Highlight: \(photo.highlight)",
            "- Shadow: \(photo.shadow)",
            "- Color: \(photo.color)",
            "- Noise Reduction: \(photo.noiseReduction)",
            "- Sharpness: \(photo.sharpness)",
            "- Clarity: \(photo.clarity)",
            "- Grain Effect: \(photo.grainEffect)",
            "- Color Chrome Effect: \(photo.colorChromeEffect)",
            "- Color Chrome Effect Blue: \(photo.colorChromeFXBlue)",
            "- White Balance: \(photo.whiteBalance)",
            "- ISO: \(photo.iso)",
            "- Exposure Compensation: \(photo.exposureCompensation)"
        ].joined(separator: "\n")
    }

    private func renderFilmIndex(_ photos: [PhotoRecipe]) -> String {
        let grouped = Dictionary(grouping: photos, by: \.film)
        var lines = ["# Film Simulations", ""]

        for film in grouped.keys.sorted() {
            lines.append("## \(film)")
            lines.append("")
            for photo in grouped[film, default: []].sorted(by: { $0.title < $1.title }) {
                lines.append("- [\(photo.title)](../notes/\(photo.title).md)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renderRecipeIndex(_ photos: [PhotoRecipe]) -> String {
        let grouped = Dictionary(grouping: photos, by: \.recipeKey)
        var lines = ["# Recipes", ""]

        for recipe in grouped.keys.sorted() {
            lines.append("## \(recipe)")
            lines.append("")
            for photo in grouped[recipe, default: []].sorted(by: { $0.title < $1.title }) {
                lines.append("- [\(photo.title)](../notes/\(photo.title).md) | \(photo.film) | \(photo.dynamicRange)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
