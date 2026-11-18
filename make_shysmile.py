#!/usr/bin/env python3
"""由 00_Shame_01 衍生「嬌羞微笑」動作 00_ShySmile_01（保留低頭/視線/身體，改嘴型與眉形）。"""
import json, sys, os
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Open-LLM-VTuber/live2d-models')
OVERRIDES = {
    'PARAM_MOUTH_FORM_01': 1.0, 'PARAM_MOUTH_POS_Y': 0.3,
    'PARAM_MOUTH_SCALE': 0.0, 'PARAM_MOUTH_SCALE_Y': 0.0,
    'PARAM_BROW_R_FORM': 0.3, 'PARAM_BROW_L_FORM': 0.3,
    'PARAM_BROW_R_ANGLE': 0.2, 'PARAM_BROW_L_ANGLE': 0.2,
    'PARAM_EYE_R_SMILE': 0.5, 'PARAM_EYE_L_SMILE': 0.5,
    'PARAM_EYE_FORM': 0.0,
    'PARAM_CHEEK_01': 1.2, 'PARAM_CHEEK_03': 0.3,
}
for m in ('emilia_4star', 'emilia_4star_ss'):
    d = os.path.join(base, m)
    src = json.load(open(os.path.join(d, 'motions/00_Shame_01.motion3.json')))
    dur = src['Meta']['Duration']
    for c in src['Curves']:
        if c['Id'] in OVERRIDES:
            c['Segments'] = [0, OVERRIDES[c['Id']], 0, dur, OVERRIDES[c['Id']]]
    tp = ts = 0
    for c in src['Curves']:
        s = c['Segments']; i = 2; n = 0; pts = 1
        while i < len(s):
            t = s[i]
            step = {0: 3, 1: 7, 2: 3, 3: 3}[t]; pts += {1: 3}.get(t, 1)
            i += step; n += 1
        ts += n; tp += pts
    src['Meta']['TotalSegmentCount'] = ts; src['Meta']['TotalPointCount'] = tp
    json.dump(src, open(os.path.join(d, 'motions/00_ShySmile_01.motion3.json'), 'w'), separators=(',', ':'))
    mj = os.path.join(d, f'{m}.model3.json')
    cfg = json.load(open(mj))
    cfg['FileReferences']['Motions']['ShySmile'] = [{'File': 'motions/00_ShySmile_01.motion3.json', 'FadeInTime': 0.4, 'FadeOutTime': 0.6}]
    json.dump(cfg, open(mj, 'w'), indent=2, ensure_ascii=False)
    print('ok', m, ts, tp)
