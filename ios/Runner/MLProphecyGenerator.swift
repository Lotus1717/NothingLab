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
            DispatchQueue.main.async {
                self?.loadProgressValue = progress
                progressCallback(progress)
            }
        }
        
        self.modelContainer = container
        self.isModelLoaded = true
    }
    
    // MARK: - 生成预言
    @objc func generateProphecy(
        battery: Int,
        brightness: Int,
        steps: Int,
        isMoving: Bool,
        ambientLight: Int,
        timeHint: String,
        dayPhase: String
    ) async throws -> String {
        
        guard let container = modelContainer else {
            throw MLProphecyError.modelNotLoaded
        }
        
        // 构建提示词 - 用中文引导模型生成短预言
        let prompt = """
        <|im_start|>system
        你是一个风趣的"废话预言家"。根据手机传感器数据，生成一句有趣、无厘头的中文预言。
        
        规则：
        - 预言必须基于传感器数据，但结果要荒诞有趣
        - 控制在 25 字以内
        - 不要评价自己，直接输出预言
        - 语气轻松幽默
        <|im_end|>
        <|im_start|>user
        当前数据：
        - 电量：\(battery)%
        - 屏幕亮度：\(brightness)%
        - 步数：\(steps)
        - 状态：\(isMoving ? "正在移动" : "静止")
        - 环境光：\(ambientLight)
        - 时段：\(dayPhase) · \(timeHint)
        
        请给我一句预言：
        <|im_end|>
        <|im_start|>assistant
        """
        
        let parameters = GenerateParameters(
            temperature: 0.9,
            topP: 0.85,
            maxTokens: 60
        )
        
        let result = try await container.perform { context in
            let input = try await context.processor.prepare(prompt: prompt)
            return try await MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            ) { [weak self] tokens in
                // 可选：实时回调每个 token
                return .more
            }
        }
        
        // 清理输出：去掉特殊 token 和多余空白
        var prophecy = result.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果输出太长，截断
        if prophecy.count > 25 {
            prophecy = String(prophecy.prefix(25)) + "…"
        }
        
        return prophecy
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
