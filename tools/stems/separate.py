#!/usr/bin/env python3
"""HT-Demucs ONNX stem separation helper for Echo Music Desktop.

Reads a 44.1 kHz stereo WAV, writes one four-channel WAV with the four stems
in this order: drums, bass, other, vocals. Only numpy, onnxruntime and
soundfile are needed at inference time; no PyTorch.

Reference inference from StemSplitio/htdemucs-onnx (MIT), adapted to emit a
single multichannel file so mpv can mute stems with one `pan` filter.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
import soundfile as sf

SOURCES = ("drums", "bass", "other", "vocals")
SAMPLE_RATE = 44100
N_SAMPLES = 343980  # 7.8 s at 44.1 kHz
OVERLAP = N_SAMPLES // 4
STRIDE = N_SAMPLES - OVERLAP


def make_window(n: int, overlap: int) -> np.ndarray:
    window = np.ones(n, dtype=np.float32)
    fade = np.linspace(0, 1, overlap, dtype=np.float32)
    window[:overlap] = fade
    window[-overlap:] = fade[::-1]
    return window


def separate(mix: np.ndarray, model_path: Path) -> np.ndarray:
    if mix.ndim != 2 or mix.shape[0] != 2:
        raise ValueError(f"expected (2, samples), got {mix.shape}")
    options = ort.SessionOptions()
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    session = ort.InferenceSession(
        str(model_path), sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    total = mix.shape[1]
    chunks = max(1, (total + STRIDE - 1) // STRIDE)
    window = make_window(N_SAMPLES, OVERLAP)
    out = np.zeros((4, 2, total), dtype=np.float32)
    weight = np.zeros(total, dtype=np.float32)
    for index in range(chunks):
        start = index * STRIDE
        end = min(start + N_SAMPLES, total)
        chunk = mix[:, start:end]
        if chunk.shape[1] < N_SAMPLES:
            chunk = np.pad(
                chunk, ((0, 0), (0, N_SAMPLES - chunk.shape[1])), mode="constant"
            )
        stems = session.run(
            ["stems"], {"mix": chunk[np.newaxis, ...].astype(np.float32)}
        )[0][0]
        length = end - start
        w = window[:length]
        out[:, :, start:end] += stems[:, :, :length] * w
        weight[start:end] += w
        print(f"PROGRESS {index + 1}/{chunks}", flush=True)
    out /= np.maximum(weight, 1e-8)
    return out


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: separate.py INPUT.wav OUTPUT.wav MODEL.onnx", file=sys.stderr)
        return 2
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    model = Path(sys.argv[3])
    if not source.exists() or not model.exists():
        print("input or model missing", file=sys.stderr)
        return 2
    audio, sample_rate = sf.read(str(source), dtype="float32", always_2d=True)
    if sample_rate != SAMPLE_RATE:
        print(f"ERROR: sample rate is {sample_rate}, expected {SAMPLE_RATE}", file=sys.stderr)
        return 2
    stems = separate(audio.T, model)
    # Four mono channels: drums, bass, other, vocals. mpv duplicates them to
    # stereo with the pan filter, so no extra bandwidth is spent on dual mono.
    mono = stems.mean(axis=1).T  # (samples, 4)
    sf.write(str(target), mono, SAMPLE_RATE, subtype="PCM_16", format="WAV")
    print(f"DONE {target}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
