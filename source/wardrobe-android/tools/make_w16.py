# 把 SigLIP2 vision_model.onnx（fp32，372MB）的大权重存成 fp16 + Cast，体积减半，计算仍是 fp32，ORT 1.15 可加载。
import sys, onnx, numpy as np
from onnx import numpy_helper, helper, TensorProto
src, dst = sys.argv[1], sys.argv[2]
m = onnx.load(src); g = m.graph; inits = []; casts = []
for t in list(g.initializer):
    a = numpy_helper.to_array(t)
    if a.dtype == np.float32 and a.size >= 4096:
        inits.append(numpy_helper.from_array(a.astype(np.float16), t.name + '_fp16'))
        casts.append(helper.make_node('Cast', [t.name + '_fp16'], [t.name], to=TensorProto.FLOAT))
        g.initializer.remove(t)
g.initializer.extend(inits); nodes = list(g.node); del g.node[:]; g.node.extend(casts + nodes)
onnx.save(m, dst)
