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

    // MARK: - 模型配置
    /// 使用 4-bit 量化的小模型（约 200MB），适合 iPhone 本地运行
    private let modelConfig = ModelConfiguration(
        id: "mlx-community/Qwen2.5-0.5B-4bit"
    )

    /// 流式输出回调（可选）
    var onToken: ((String) -> Void)?

    // MARK: - 加载模型
    @objc func loadModel(progressCallback: @escaping (Double) -> Void) async throws {
        guard !isModelLoaded else { return }
        isDownloading = true
        loadProgressValue = 0

        defer {
            isDownloading = false
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
    }

    // MARK: - 生成预言
    @objc func generateProphecy(prompt: String) async throws -> String {

        guard let container = modelContainer else {
            throw MLProphecyError.modelNotLoaded
        }

        let parameters = GenerateParameters(
            maxTokens: 64,
            temperature: 0.85,
            topP: 0.9
        )

        let result = try await container.perform { context in
            let userInput = UserInput(prompt: prompt)
            let input = try await context.processor.prepare(input: userInput)
            let iterator = try TokenIterator(
                input: input, model: context.model, parameters: parameters)
            let generateResult: GenerateResult = MLXLMCommon.generate(
                input: input, context: context, iterator: iterator
            ) { _ in .more }
            Stream.gpu.synchronize()
            return generateResult
        }

        // 仅做基础清理，详细截断交给 Dart normalizer
        var prophecy = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        for token in ["", "<|endoftext|>"] {
            prophecy = prophecy.replacingOccurrences(of: token, with: "")
        }
        return prophecy.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // MARK: - 卸载模型（释放内存）
    @objc func unloadModel() {
        modelContainer = nil
        isModelLoaded = false
        loadProgressValue = 0
    }
}

// MARK: - 错误类型
enum MLProphecyError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "模型尚未加载完成"
        case .generationFailed(let detail):
            return "生成失败：\(detail)"
        }
    }
}
