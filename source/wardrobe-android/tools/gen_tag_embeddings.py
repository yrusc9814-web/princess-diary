# 依赖：pip install onnxruntime tokenizers numpy；需同目录 tokenizer.json 与 onnx/text_model.onnx
# （来自 onnx-community/siglip2-base-patch16-224-ONNX）。改标签后重跑，输出 tag_embeddings.json 放到 assets/models/。
# 每个标签 = 若干中英同义词 × 若干句式模板，全部编码后取平均作为该标签的"原型向量"。
import json, sys, numpy as np, onnxruntime as ort
from tokenizers import Tokenizer
tok = Tokenizer.from_file('tokenizer.json'); sess = ort.InferenceSession('onnx/text_model.onnx')
PAD = tok.token_to_id('<pad>'); EOS = tok.token_to_id('<eos>')
def embed(texts):
    out = []
    for i in range(0, len(texts), 32):
        ids = []
        for t in texts[i:i+32]:
            e = tok.encode(t.lower(), add_special_tokens=False).ids[:63] + [EOS]; ids.append(e + [PAD]*(64-len(e)))
        out.append(sess.run(['pooler_output'], {'input_ids': np.array(ids, dtype=np.int64)})[0])
    v = np.concatenate(out); return v / np.linalg.norm(v, axis=1, keepdims=True)

L = json.load(open(sys.argv[1] if len(sys.argv) > 1 else 'labels.json'))
out = {'model': 'google/siglip2-base-patch16-224', 'dim': 768, 'image_size': 224, 'mean': [0.5]*3, 'std': [0.5]*3,
       'vision_output': 'pooler_output', 'note': '分数 = L2归一化图像向量 · 标签向量；多选组按 multi 规则取', 'groups': {}, 'rules': {}}
for g, spec in L.items():
    tpl_en, tpl_zh = spec['templates']
    items = []
    for it in spec['labels']:
        texts = [t.format(w) for w in it['en'] for t in tpl_en] + [t.format(w) for w in it['zh'] for t in tpl_zh]
        v = embed(texts).mean(0); v /= np.linalg.norm(v)
        items.append({'key': it['key'], 'syn': it['zh'] + it['en'], 'vec': [round(float(x), 5) for x in v]})
    out['groups'][g] = items
    if 'multi' in spec: out['rules'][g] = spec['multi']
json.dump(out, open('tag_embeddings.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print('groups', {g: len(v) for g, v in out['groups'].items()}, 'synonyms', sum(len(i['syn']) for v in out['groups'].values() for i in v))
