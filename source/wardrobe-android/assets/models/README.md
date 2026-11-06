本目录模型均为开源，可自由分发：

1. u2netp.onnx：抠图（U²-Net，Apache-2.0，rembg 官方发布，4,574,861 字节，MD5 8e83ca70e441ab06c318d82300c84806）。输入 1×3×320×320。
2. siglip2_vision.onnx：本地打标（google/siglip2-base-patch16-224，Apache-2.0，来源 onnx-community/siglip2-base-patch16-224-ONNX 的 vision_model.onnx，经 tools/make_w16.py 把权重存为 fp16，约 186MB，计算仍为 fp32）。
   - 输入 pixel_values [1,3,224,224]：铺白底 → 224×224 双三次缩放 → (x/255-0.5)/0.5，RGB，NCHW
   - 输出取 pooler_output [1,768]，L2 归一化
3. tag_embeddings.json：标签向量，用 SigLIP2 文字模型离线生成（tools/gen_tag_embeddings.py + tools/labels.json），9 组：categoryL2 / colors / materials / warmth / fit / length / layerRole / styles / seasons，共 367 个中英同义词，每项 {key, syn, vec[768]}。打分 = 图像向量 · 标签向量，每组取最高分（季节取前 2）。与原版对比见 docs/tagger_benchmark.md。

为什么不用更小的版本（沙箱实测 18 张商品图，品类/颜色）：
- 本版（fp16 存权重）：品类 18/18，颜色 18/18
- vision_model_int8.onnx（95MB）：品类 15/18，颜色 17/18，量化损失明显
- vision_model_q4.onnx（63MB）：18/18，但需要 ORT ≥1.17 的 MatMulNBits，当前 Flutter 插件 onnxruntime 1.4.1 内置 ORT 1.15，加载不了。若换成内置新版 ORT 的插件，可改用 q4。

不要放原 App 安装包里的模型文件（model_b.ort、text_embeddings.json 等）。
