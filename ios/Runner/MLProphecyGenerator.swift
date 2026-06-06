import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// 使用 Apple MLX 框架在本地运行小模型，生成真正的"废话预言"
@objc public class MLProphecyGenerator: NSObject {

    // MARK: - 单例
    @objc static let shared = MLProphecyGenerator()

    // MARK: - 状态
    private var modelContainer: ModelContainer?
    private var loadProgressValue: Double = 0
    @objc private(set) var isModelLoaded = false
    @objc var isDownloading = false

    @objc var loadProgress: Double {
        return loadProgressValue
    }

    // MARK: - 内置模型（Instruct 版）
    private static let bundledModelFolder = "Qwen2.5-0.5B-Instruct-4bit"

    private static let requiredModelFiles = [
        "config.json",
        "model.safetensors",
        "tokenizer.json",
        "tokenizer_config.json",
    ]

    private var modelConfig: ModelConfiguration {
        ModelConfiguration(
            directory: Self.bundledModelDirectory(),
            extraEOSTokens: ["<|im_end|>", "<|endoftext|>"]
        )
    }

    /// 流式输出回调（可选）
    var onToken: ((String) -> Void)?

    // MARK: - 加载模型
    @objc func loadModel(progressCallback: @escaping (Double) -> Void) async throws {
        guard !isModelLoaded else { return }

        loadProgressValue = 0
        DispatchQueue.main.async {
            progressCallback(0)
        }

        let modelDirectory = Self.bundledModelDirectory()
        guard Self.validateBundledModel(at: modelDirectory) else {
            throw MLProphecyError.bundledModelMissing
        }

        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfig
        ) { [weak self] progress in
            let fraction = progress.fractionCompleted
            DispatchQueue.main.async {
                self?.loadProgressValue = fraction
                progressCallback(fraction)
            }
        }

        self.modelContainer = container
        self.isModelLoaded = true
        self.loadProgressValue = 1
        DispatchQueue.main.async {
            progressCallback(1)
        }
    }

    // MARK: - 生成预言
    @objc func generateProphecy(systemPrompt: String, userPrompt: String) async throws -> String {

        guard let container = modelContainer else {
            throw MLProphecyError.modelNotLoaded
        }

        let parameters = GenerateParameters(
            maxTokens: 56,
            temperature: 0.7,
            topP: 0.85,
            repetitionPenalty: 1.15,
            repetitionContextSize: 40
        )

        let result = try await container.perform { context in
            let userInput = UserInput(chat: [
                .system(systemPrompt),
                .user(userPrompt),
            ])
            let input = try await context.processor.prepare(input: userInput)
            let iterator = try TokenIterator(
                input: input, model: context.model, parameters: parameters)
            let generateResult: GenerateResult = MLXLMCommon.generate(
                input: input, context: context, iterator: iterator
            ) { _ in .more }
            Stream.gpu.synchronize()
            return generateResult
        }

        return Self.cleanModelOutput(result.output)
    }

    // MARK: - 卸载模型（释放内存）
    @objc func unloadModel() {
        modelContainer = nil
        isModelLoaded = false
        loadProgressValue = 0
    }

    // MARK: - 内置模型路径
    private static func bundledModelDirectory() -> URL {
        // Xcode 打包后模型文件夹在 .app 根目录
        if let url = Bundle.main.url(
            forResource: bundledModelFolder,
            withExtension: nil
        ) {
            return url
        }
        if let url = Bundle.main.url(
            forResource: bundledModelFolder,
            withExtension: nil,
            subdirectory: "Models"
        ) {
            return url
        }
        return Bundle.main.bundleURL.appendingPathComponent(bundledModelFolder)
    }

    private static func validateBundledModel(at directory: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return false }
        return requiredModelFiles.allSatisfy {
            fm.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }

    private static func cleanModelOutput(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let leakMarkers = [
            "<|im_end|>", "<|im_start|>", "<|endoftext|>",
            "上一句", "当前状态", "当前传感器", "传感器", "参考", "数据：", "写一条", "写一句", "示例", "编号",
        ]
        for marker in leakMarkers {
            if let range = text.range(of: marker) {
                text = String(text[..<range.lowerBound])
            }
        }
        text = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        for token in ["<|im_end|>", "<|im_start|>", "<|endoftext|>", "assistant", "user", "system"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

// MARK: - 错误类型
enum MLProphecyError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)
    case bundledModelMissing

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "模型尚未加载完成"
        case .generationFailed(let detail):
            return "生成失败：\(detail)"
        case .bundledModelMissing:
            return "内置千问模型缺失，请重新安装应用"
        }
    }
}
