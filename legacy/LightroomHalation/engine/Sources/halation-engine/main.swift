import Foundation
import AppKit
import CoreImage
import CoreGraphics
import ImageIO

private let version = "1.0.0"

enum EngineError: Error, CustomStringConvertible {
    case usage(String)
    case io(String)
    case processing(String)

    var description: String {
        switch self {
        case .usage(let message): return message
        case .io(let message): return message
        case .processing(let message): return message
        }
    }
}

enum RenderMode: String, Codable { case final, halo, matte }

struct RenderConfig: Codable {
    var input: String = ""
    var output: String = ""
    var halationAmount: Double = 0.35
    var halationRadius: Double = 18
    var threshold: Double = 0.72
    var softness: Double = 0.25
    var warmth: Double = 0.65
    var bloomAmount: Double = 0.2
    var bloomRadius: Double = 22
    var grainAmount: Double = 0
    var grainSize: Double = 1
    var vignette: Double = 0
    var chromaticAberration: Double = 0
    var fade: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var mode: RenderMode = .final

    private enum CodingKeys: String, CodingKey {
        case input, output, halationAmount, halationRadius, threshold, softness, warmth, bloomAmount, bloomRadius, grainAmount, grainSize, vignette, chromaticAberration, fade, contrast, saturation, mode
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        input = try values.decodeIfPresent(String.self, forKey: .input) ?? ""
        output = try values.decodeIfPresent(String.self, forKey: .output) ?? ""
        halationAmount = try values.decodeIfPresent(Double.self, forKey: .halationAmount) ?? 0.35
        halationRadius = try values.decodeIfPresent(Double.self, forKey: .halationRadius) ?? 18
        threshold = try values.decodeIfPresent(Double.self, forKey: .threshold) ?? 0.72
        softness = try values.decodeIfPresent(Double.self, forKey: .softness) ?? 0.25
        warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0.65
        bloomAmount = try values.decodeIfPresent(Double.self, forKey: .bloomAmount) ?? 0.2
        bloomRadius = try values.decodeIfPresent(Double.self, forKey: .bloomRadius) ?? 22
        grainAmount = try values.decodeIfPresent(Double.self, forKey: .grainAmount) ?? 0
        grainSize = try values.decodeIfPresent(Double.self, forKey: .grainSize) ?? 1
        vignette = try values.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        chromaticAberration = try values.decodeIfPresent(Double.self, forKey: .chromaticAberration) ?? 0
        fade = try values.decodeIfPresent(Double.self, forKey: .fade) ?? 0
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 0
        saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 0
        mode = try values.decodeIfPresent(RenderMode.self, forKey: .mode) ?? .final
    }

    mutating func validate() throws {
        guard !input.isEmpty else { throw EngineError.usage("--input is required") }
        guard !output.isEmpty else { throw EngineError.usage("--output is required") }
        guard halationAmount >= 0, halationRadius >= 0, threshold >= 0, threshold <= 1,
              softness >= 0, warmth >= 0, warmth <= 1, bloomAmount >= 0, bloomRadius >= 0,
              grainAmount >= 0, grainAmount <= 1, grainSize > 0, vignette >= 0, vignette <= 1,
              chromaticAberration >= 0, fade >= 0, fade <= 1, contrast >= -1, contrast <= 1,
              saturation >= -1, saturation <= 1 else {
            throw EngineError.usage("numeric controls are outside their valid ranges")
        }
    }
}

private struct ArgumentParser {
    static func parse(_ args: [String]) throws -> RenderConfig {
        if args.contains("--help") || args.contains("-h") {
            print(Self.usage)
            throw EngineError.usage("")
        }
        if args.contains("--version") {
            print(version)
            throw EngineError.usage("")
        }
        var config = RenderConfig()
        var index = 0
        while index < args.count {
            let token = args[index]
            guard token.hasPrefix("--") else { throw EngineError.usage("unexpected argument: \(token)") }
            guard index + 1 < args.count else { throw EngineError.usage("missing value for \(token)") }
            let value = args[index + 1]
            switch token {
            case "--config":
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: value))
                    config = try JSONDecoder().decode(RenderConfig.self, from: data)
                } catch { throw EngineError.usage("invalid JSON config: \(error.localizedDescription)") }
            case "--input": config.input = value
            case "--output": config.output = value
            case "--halation-amount": config.halationAmount = try number(value, token)
            case "--halation-radius": config.halationRadius = try number(value, token)
            case "--threshold": config.threshold = try number(value, token)
            case "--softness": config.softness = try number(value, token)
            case "--warmth": config.warmth = try number(value, token)
            case "--bloom-amount": config.bloomAmount = try number(value, token)
            case "--bloom-radius": config.bloomRadius = try number(value, token)
            case "--grain-amount": config.grainAmount = try number(value, token)
            case "--grain-size": config.grainSize = try number(value, token)
            case "--vignette": config.vignette = try number(value, token)
            case "--chromatic-aberration": config.chromaticAberration = try number(value, token)
            case "--fade": config.fade = try number(value, token)
            case "--contrast": config.contrast = try number(value, token)
            case "--saturation": config.saturation = try number(value, token)
            case "--mode":
                guard let mode = RenderMode(rawValue: value.lowercased()) else { throw EngineError.usage("--mode must be final, halo, or matte") }
                config.mode = mode
            default: throw EngineError.usage("unknown option: \(token)")
            }
            index += 2
        }
        try config.validate()
        return config
    }

    static func number(_ value: String, _ option: String) throws -> Double {
        guard let number = Double(value), number.isFinite else { throw EngineError.usage("invalid number for \(option): \(value)") }
        return number
    }

    static let usage = """
    halation-engine \(version)
    Usage: halation-engine --input PATH --output PATH [controls]
      --mode final|halo|matte
      --config PATH (JSON config)
    """
}

private final class ImageProcessor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func process(_ config: RenderConfig) throws {
        let inputURL = URL(fileURLWithPath: config.input).standardizedFileURL.resolvingSymlinksInPath()
        let outputURL = URL(fileURLWithPath: config.output).standardizedFileURL.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: inputURL.path) else { throw EngineError.io("input does not exist: \(inputURL.path)") }
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw EngineError.io("unable to decode input image: \(inputURL.path)") }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let image = CIImage(cgImage: cgImage)
        let result = render(image, config: config)
        guard let rendered = context.createCGImage(result, from: result.extent.integral) else { throw EngineError.processing("Core Image could not create output") }
        let parent = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let suffix = outputURL.pathExtension.isEmpty ? "png" : outputURL.pathExtension
        let tempURL = parent.appendingPathComponent(".halation-\(UUID().uuidString).tmp.\(suffix)")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard let uti = outputUTI(for: suffix), let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, uti, 1, nil) else { throw EngineError.io("unsupported output extension; use png, jpg, jpeg, or tiff") }
        CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw EngineError.io("unable to finalize output image") }
        if FileManager.default.fileExists(atPath: outputURL.path) { _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: tempURL) }
        else { try FileManager.default.moveItem(at: tempURL, to: outputURL) }
    }

    private func outputUTI(for ext: String) -> CFString? {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "public.jpeg" as CFString
        case "tif", "tiff": return "public.tiff" as CFString
        case "png", "": return "public.png" as CFString
        default: return nil
        }
    }

    private func filter(_ name: String, _ image: CIImage, _ values: [String: Any] = [:]) -> CIImage {
        guard let f = CIFilter(name: name) else { return image }
        f.setValue(image, forKey: kCIInputImageKey)
        for (key, value) in values { f.setValue(value, forKey: key) }
        return f.outputImage ?? image
    }

    private func alpha(_ image: CIImage, _ amount: Double) -> CIImage {
        let a = max(0, min(1, amount))
        return filter("CIColorMatrix", image, [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: a)
        ])
    }

    private func render(_ input: CIImage, config: RenderConfig) -> CIImage {
        let extent = input.extent
        let base = filter("CIColorControls", input, [kCIInputContrastKey: CGFloat(1 + config.contrast), kCIInputSaturationKey: CGFloat(1 + config.saturation)])
        let luminance = filter("CIColorControls", base, [kCIInputSaturationKey: 0, kCIInputBrightnessKey: CGFloat(-config.threshold), kCIInputContrastKey: CGFloat(3 + config.softness * 8)])
        let mask = filter("CIGaussianBlur", luminance, [kCIInputRadiusKey: CGFloat(max(0.1, config.softness * 3))]).cropped(to: extent)
        let blurHalo = filter("CIGaussianBlur", base, [kCIInputRadiusKey: CGFloat(max(0.1, config.halationRadius))]).cropped(to: extent)
        let warm = filter("CIColorMatrix", blurHalo, [
            "inputRVector": CIVector(x: 1 + CGFloat(config.warmth) * 0.45, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.62 + CGFloat(config.warmth) * 0.25, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.38, w: 0)
        ])
        let halo = alpha(filter("CIBlendWithMask", warm, [kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: extent), kCIInputMaskImageKey: mask]), config.halationAmount)
        var result = base
        switch config.mode {
        case .final:
            result = filter("CIScreenBlendMode", halo, [kCIInputBackgroundImageKey: result])
            if config.bloomAmount > 0 {
                let bloom = alpha(filter("CIGaussianBlur", result, [kCIInputRadiusKey: CGFloat(max(0.1, config.bloomRadius))]).cropped(to: extent), config.bloomAmount)
                result = filter("CIScreenBlendMode", bloom, [kCIInputBackgroundImageKey: result])
            }
            if config.fade > 0 {
                let lift = CGFloat(config.fade) * 0.12
                result = filter("CIColorMatrix", result, [
                    "inputRVector": CIVector(x: 1 - CGFloat(config.fade) * 0.12, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1 - CGFloat(config.fade) * 0.12, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1 - CGFloat(config.fade) * 0.12, w: 0),
                    "inputBiasVector": CIVector(x: lift, y: lift, z: lift, w: 0)
                ])
            }
            if config.vignette > 0 { result = filter("CIVignette", result, [kCIInputIntensityKey: CGFloat(config.vignette) * 2, kCIInputRadiusKey: 1.5]) }
            if config.grainAmount > 0 {
                let noise = filter("CIRandomGenerator", CIImage.empty()).cropped(to: extent)
                let grain = alpha(filter("CIColorControls", noise, [kCIInputSaturationKey: 0, kCIInputContrastKey: CGFloat(1 + config.grainSize * 2)]), config.grainAmount * 0.18)
                result = filter("CIOverlayBlendMode", grain, [kCIInputBackgroundImageKey: result])
            }
            if config.chromaticAberration > 0 {
                let shift = CGFloat(min(12, config.chromaticAberration * 3))
                var translation = CGAffineTransform(translationX: shift, y: 0)
                let transformValue = NSValue(bytes: &translation, objCType: "{CGAffineTransform=dddd}")
                let shifted = filter("CIAffineTransform", result, [kCIInputTransformKey: transformValue]).cropped(to: extent)
                result = filter("CIScreenBlendMode", alpha(shifted, config.chromaticAberration * 0.18), [kCIInputBackgroundImageKey: result])
            }
        case .halo: result = halo
        case .matte: result = mask
        }
        return result.cropped(to: extent)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    let config = try ArgumentParser.parse(arguments)
    try ImageProcessor().process(config)
} catch let error as EngineError {
    if !error.description.isEmpty { fputs("halation-engine: \(error.description)\n", stderr) }
    switch error {
    case .usage: exit(2)
    case .io: exit(3)
    case .processing: exit(4)
    }
} catch {
    fputs("halation-engine: \(error.localizedDescription)\n", stderr)
    exit(4)
}
