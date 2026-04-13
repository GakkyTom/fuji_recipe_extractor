import Foundation

let unknownValue = "Unknown"

enum CopyMode: String, CaseIterable, Identifiable, Codable {
    case none
    case recipe
    case film

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Do Not Copy by Group"
        case .recipe: return "Recipe"
        case .film: return "Film"
        }
    }
}

struct ScanConfiguration {
    let inputDirectory: URL
    let outputDirectory: URL
    let copyMode: CopyMode
    let dryRun: Bool
    let verbose: Bool
}

struct ExifToolRecord: Decodable {
    let sourceFile: String?
    let filmMode: String?
    let cameraProfile: String?
    let dynamicRange: String?
    let developmentDynamicRange: String?
    let highlightTone: String?
    let shadowTone: String?
    let saturation: String?
    let noiseReduction: String?
    let sharpness: String?
    let clarity: String?
    let grainEffectRoughness: String?
    let grainEffectSize: String?
    let colorChromeEffect: String?
    let colorChromeFXBlue: String?
    let whiteBalance: String?
    let whiteBalanceFineTune: String?
    let iso: String?
    let exposureCompensation: String?

    enum CodingKeys: String, CodingKey {
        case sourceFile = "SourceFile"
        case filmMode = "FilmMode"
        case cameraProfile = "CameraProfile"
        case dynamicRange = "DynamicRange"
        case developmentDynamicRange = "DevelopmentDynamicRange"
        case highlightTone = "HighlightTone"
        case shadowTone = "ShadowTone"
        case saturation = "Saturation"
        case noiseReduction = "NoiseReduction"
        case sharpness = "Sharpness"
        case clarity = "Clarity"
        case grainEffectRoughness = "GrainEffectRoughness"
        case grainEffectSize = "GrainEffectSize"
        case colorChromeEffect = "ColorChromeEffect"
        case colorChromeFXBlue = "ColorChromeFXBlue"
        case whiteBalance = "WhiteBalance"
        case whiteBalanceFineTune = "WhiteBalanceFineTune"
        case iso = "ISO"
        case exposureCompensation = "ExposureCompensation"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sourceFile = container.decodeFlexibleString(forKey: .sourceFile)
        filmMode = container.decodeFlexibleString(forKey: .filmMode)
        cameraProfile = container.decodeFlexibleString(forKey: .cameraProfile)
        dynamicRange = container.decodeFlexibleString(forKey: .dynamicRange)
        developmentDynamicRange = container.decodeFlexibleString(forKey: .developmentDynamicRange)
        highlightTone = container.decodeFlexibleString(forKey: .highlightTone)
        shadowTone = container.decodeFlexibleString(forKey: .shadowTone)
        saturation = container.decodeFlexibleString(forKey: .saturation)
        noiseReduction = container.decodeFlexibleString(forKey: .noiseReduction)
        sharpness = container.decodeFlexibleString(forKey: .sharpness)
        clarity = container.decodeFlexibleString(forKey: .clarity)
        grainEffectRoughness = container.decodeFlexibleString(forKey: .grainEffectRoughness)
        grainEffectSize = container.decodeFlexibleString(forKey: .grainEffectSize)
        colorChromeEffect = container.decodeFlexibleString(forKey: .colorChromeEffect)
        colorChromeFXBlue = container.decodeFlexibleString(forKey: .colorChromeFXBlue)
        whiteBalance = container.decodeFlexibleString(forKey: .whiteBalance)
        whiteBalanceFineTune = container.decodeFlexibleString(forKey: .whiteBalanceFineTune)
        iso = container.decodeFlexibleString(forKey: .iso)
        exposureCompensation = container.decodeFlexibleString(forKey: .exposureCompensation)
    }
}

struct PhotoRecipe {
    let sourceFileName: String
    let sourcePath: String
    let title: String
    let sourceType: String
    let film: String
    let dynamicRange: String
    let highlight: String
    let shadow: String
    let color: String
    let noiseReduction: String
    let sharpness: String
    let clarity: String
    let grainEffect: String
    let colorChromeEffect: String
    let colorChromeFXBlue: String
    let whiteBalance: String
    let iso: String
    let exposureCompensation: String

    var id: String {
        sourcePath
    }

    var recipeKey: String {
        "\(normalizeToken(film))_\(normalizeToken(dynamicRange))"
    }

    var filmKey: String {
        normalizeToken(film)
    }
}

struct ScanResult {
    let photos: [PhotoRecipe]
    let summary: String
}

enum AppError: LocalizedError {
    case invalidInputDirectory(String)
    case exifToolMissing(String)
    case processFailed(String)
    case invalidExifJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidInputDirectory(let path):
            return "Input directory does not exist: \(path)"
        case .exifToolMissing(let path):
            return "exiftool not found or not executable: \(path)"
        case .processFailed(let message):
            return message
        case .invalidExifJSON(let message):
            return message
        }
    }
}

func buildPhotoRecipe(from record: ExifToolRecord) -> PhotoRecipe {
    let sourcePath = normalized(record.sourceFile)
    let fileURL = sourcePath == unknownValue ? nil : URL(fileURLWithPath: sourcePath)
    let fileName = fileURL?.lastPathComponent ?? unknownValue
    let title = fileURL?.deletingPathExtension().lastPathComponent ?? unknownValue

    return PhotoRecipe(
        sourceFileName: fileName,
        sourcePath: sourcePath,
        title: title,
        sourceType: normalizeSourceType(cameraProfile: record.cameraProfile),
        film: normalizeFilm(filmMode: record.filmMode, cameraProfile: record.cameraProfile),
        dynamicRange: normalizeDynamicRange(dynamicRange: record.dynamicRange, developmentDynamicRange: record.developmentDynamicRange),
        highlight: normalizeTone(record.highlightTone),
        shadow: normalizeTone(record.shadowTone),
        color: normalizeTone(record.saturation),
        noiseReduction: normalizeTone(record.noiseReduction),
        sharpness: normalizeTone(record.sharpness),
        clarity: normalizeTone(record.clarity),
        grainEffect: normalizeGrainEffect(roughness: record.grainEffectRoughness, size: record.grainEffectSize),
        colorChromeEffect: normalized(record.colorChromeEffect),
        colorChromeFXBlue: normalized(record.colorChromeFXBlue),
        whiteBalance: normalizeWhiteBalance(whiteBalance: record.whiteBalance, fineTune: record.whiteBalanceFineTune),
        iso: normalized(record.iso),
        exposureCompensation: normalized(record.exposureCompensation)
    )
}

func normalized(_ value: String?) -> String {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? unknownValue : trimmed
}

func normalizeDynamicRange(dynamicRange: String?, developmentDynamicRange: String?) -> String {
    let value = normalized(dynamicRange)
    if value.uppercased().hasPrefix("DR") {
        return value.uppercased()
    }

    switch developmentDynamicRange?.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "100": return "DR100"
    case "200": return "DR200"
    case "400": return "DR400"
    default: return value
    }
}

func normalizeSourceType(cameraProfile: String?) -> String {
    let cameraProfileValue = normalized(cameraProfile)
    if cameraProfileValue.lowercased() == "embedded" {
        return "Camera JPEG"
    }
    if cameraProfileValue != unknownValue {
        return "Lightroom RAW"
    }
    return "Camera JPEG"
}

func normalizeFilm(filmMode: String?, cameraProfile: String?) -> String {
    let filmModeValue = normalized(filmMode)
    if filmModeValue != unknownValue {
        return filmModeValue
    }

    let cameraProfileValue = normalized(cameraProfile)
    if cameraProfileValue == unknownValue || cameraProfileValue.lowercased() == "embedded" {
        return unknownValue
    }

    let stripped = cameraProfileValue.replacingOccurrences(
        of: #"^Camera\s+"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    return stripped.isEmpty ? unknownValue : stripped
}

func normalizeTone(_ value: String?) -> String {
    let normalizedValue = normalized(value)
    let lowered = normalizedValue.lowercased()

    if lowered.contains("(normal)") {
        return "0"
    }
    if lowered.contains("(hard)") || lowered.contains("(soft)") {
        return normalizedValue.split(separator: " ", maxSplits: 1).first.map(String.init) ?? normalizedValue
    }
    return normalizedValue
}

func normalizeGrainEffect(roughness: String?, size: String?) -> String {
    let roughnessValue = normalized(roughness)
    let sizeValue = normalized(size)

    if roughnessValue.lowercased() == "off" || sizeValue.lowercased() == "off" {
        return "Off"
    }
    if roughnessValue == unknownValue && sizeValue == unknownValue {
        return unknownValue
    }

    return [roughnessValue, sizeValue]
        .filter { $0 != unknownValue }
        .joined(separator: ", ")
}

func normalizeWhiteBalance(whiteBalance: String?, fineTune: String?) -> String {
    let whiteBalanceValue = normalized(whiteBalance)
    if whiteBalanceValue == unknownValue {
        return unknownValue
    }

    let fineTuneValue = normalized(fineTune)
    if fineTuneValue == unknownValue {
        return whiteBalanceValue
    }

    let compacted = fineTuneValue
        .replacingOccurrences(of: "Red", with: "R")
        .replacingOccurrences(of: "Blue", with: "B")
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"([RB])\s*([+-]\d+)"#, with: "$1$2", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return "\(whiteBalanceValue) (\(compacted))"
}

func normalizeToken(_ value: String) -> String {
    let collapsed = value.replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "", options: .regularExpression)
    return collapsed.isEmpty ? unknownValue : collapsed
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return String(boolValue)
        }
        return nil
    }
}
