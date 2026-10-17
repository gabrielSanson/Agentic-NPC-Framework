"""Speech-to-text server for the CakeWorks demo: one OpenAI-style transcription endpoint around NVIDIA Parakeet.

This file is our own code, under the repository's MIT licence. It wraps the model
nvidia/parakeet-tdt-0.6b-v2, which NVIDIA publishes under CC-BY-4.0
(https://creativecommons.org/licenses/by/4.0/). Credit in the demo: "Speech recognition: NVIDIA Parakeet TDT
0.6B v2, CC-BY-4.0". The model ID is inferred from the plan: check it on Hugging Face before the first run.

The server binds to the address given on the command line. The demo uses 127.0.0.1 only. It has no authentication.
Resampling is not done here: the framework always sends 16 kHz mono WAV, and anything else is refused.
"""

import argparse
import io
import os
import tempfile
import threading
from contextlib import asynccontextmanager
from typing import Any, AsyncIterator

import soundfile as sf
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse

MODEL_ID = "nvidia/parakeet-tdt-0.6b-v2"  # check on Hugging Face
REQUIRED_RATE = 16000

# "model" is None until the background load finishes. "use_cpu" comes from the command line.
state: dict[str, Any] = {"model": None, "use_cpu": False, "error": None}


def load_model(use_cpu: bool) -> Any:
    """Loads the model once, on CUDA when it is available and --cpu was not given."""
    import torch
    from nemo.collections.asr.models import ASRModel

    device = "cpu" if use_cpu or not torch.cuda.is_available() else "cuda"
    model = ASRModel.from_pretrained(MODEL_ID)
    model.eval()
    model = model.to(device)
    return model


def _load_in_background() -> None:
    try:
        state["model"] = load_model(bool(state["use_cpu"]))
    except Exception as exc:  # reported by /health, never silently dropped
        state["error"] = str(exc)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    # Loading takes a while, so it runs in a thread: /health answers 503 until the model is ready.
    threading.Thread(target=_load_in_background, daemon=True).start()
    yield


app = FastAPI(title="CakeWorks Parakeet wrapper", lifespan=lifespan)


@app.get("/health")
def health() -> JSONResponse:
    if state["error"] is not None:
        return JSONResponse({"status": "error", "detail": state["error"]}, status_code=503)
    if state["model"] is None:
        return JSONResponse({"status": "loading"}, status_code=503)
    return JSONResponse({"status": "ok"})


def _text_of(hypotheses: Any) -> str:
    """NeMo returns a list of hypotheses (or plain strings, depending on the version). Take the first one's text."""
    if isinstance(hypotheses, tuple):
        hypotheses = hypotheses[0]
    first = hypotheses[0] if hypotheses else ""
    return str(getattr(first, "text", first)).strip()


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form("parakeet"),  # accepted for compatibility; only one model is loaded
    response_format: str = Form("json"),
) -> Any:
    loaded = state["model"]
    if loaded is None:
        raise HTTPException(status_code=503, detail="model is not loaded yet")
    data = await file.read()
    try:
        info = sf.info(io.BytesIO(data))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"not a readable audio file: {exc}") from exc
    if info.samplerate != REQUIRED_RATE or info.channels != 1:
        raise HTTPException(status_code=400, detail="need 16 kHz mono WAV; resampling is not done here")

    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        with open(path, "wb") as handle:
            handle.write(data)
        text = _text_of(loaded.transcribe([path]))
    finally:
        os.remove(path)

    if response_format == "text":
        return PlainTextResponse(text)
    return {"text": text}


def main() -> None:
    parser = argparse.ArgumentParser(description="Parakeet transcription server for the CakeWorks demo.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8010)
    parser.add_argument("--cpu", action="store_true", help="run on the CPU even when CUDA is available")
    args = parser.parse_args()
    state["use_cpu"] = args.cpu
    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
