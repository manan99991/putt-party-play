import Foundation
import TensorFlowLiteC

/// One TensorFlow Lite model, ready to run: float32 in, float32 out. Not thread-safe; one per worker.
public final class Lite {
    private let model: OpaquePointer
    private let options: OpaquePointer
    private let interpreter: OpaquePointer
    private let data: Data

    /// The model in `url`, or nil if it can't be loaded.
    public init?(url: URL, threads: Int32 = 2) {
        guard let d = try? Data(contentsOf: url) else { return nil }
        data = d
        guard let m = d.withUnsafeBytes({ TfLiteModelCreate($0.baseAddress, d.count) }) else { return nil }
        guard let o = TfLiteInterpreterOptionsCreate() else { TfLiteModelDelete(m); return nil }
        TfLiteInterpreterOptionsSetNumThreads(o, threads)
        guard let i = TfLiteInterpreterCreate(m, o) else { TfLiteInterpreterOptionsDelete(o); TfLiteModelDelete(m); return nil }
        guard TfLiteInterpreterAllocateTensors(i) == kTfLiteOk else {
            TfLiteInterpreterDelete(i); TfLiteInterpreterOptionsDelete(o); TfLiteModelDelete(m); return nil
        }
        model = m; options = o; interpreter = i
    }

    deinit {
        TfLiteInterpreterDelete(interpreter)
        TfLiteInterpreterOptionsDelete(options)
        TfLiteModelDelete(model)
    }

    /// The shape of input `i` (e.g. [1, 256, 256, 3]).
    public func inputShape(_ i: Int32 = 0) -> [Int] {
        guard let t = TfLiteInterpreterGetInputTensor(interpreter, i) else { return [] }
        return (0..<TfLiteTensorNumDims(t)).map { Int(TfLiteTensorDim(t, $0)) }
    }

    public var outputCount: Int { Int(TfLiteInterpreterGetOutputTensorCount(interpreter)) }

    /// Runs the model on `input` (exactly the input's element count) and returns every output as flat floats.
    public func run(_ input: [Float]) -> [[Float]]? {
        guard let t = TfLiteInterpreterGetInputTensor(interpreter, 0) else { return nil }
        guard TfLiteTensorByteSize(t) == input.count * 4 else { return nil }
        let ok = input.withUnsafeBytes { TfLiteTensorCopyFromBuffer(t, $0.baseAddress, $0.count) }
        guard ok == kTfLiteOk, TfLiteInterpreterInvoke(interpreter) == kTfLiteOk else { return nil }
        var outs: [[Float]] = []
        for k in 0..<TfLiteInterpreterGetOutputTensorCount(interpreter) {
            guard let o = TfLiteInterpreterGetOutputTensor(interpreter, k) else { return nil }
            var buf = [Float](repeating: 0, count: TfLiteTensorByteSize(o) / 4)
            let r = buf.withUnsafeMutableBytes { TfLiteTensorCopyToBuffer(o, $0.baseAddress, $0.count) }
            guard r == kTfLiteOk else { return nil }
            outs.append(buf)
        }
        return outs
    }
}
