"""Screenshot tool implementation for OCR capture."""

from typing import Dict, Any, Optional
import os
import tempfile
import subprocess
import shutil

from ...debug import debug_log
from ..base import Tool, ToolContext
from ..types import ToolExecutionResult


# KITNIJI WINDOWS SCREENSHOT
def _ocr_image(path: str) -> str:
    """Return OCR text from an image when OCR support is available."""
    try:
        import pytesseract  # type: ignore
        from PIL import Image  # type: ignore

        tess = shutil.which("tesseract")
        if tess:
            pytesseract.pytesseract.tesseract_cmd = tess

        with Image.open(path) as im:
            text = pytesseract.image_to_string(im)

        return text.strip() if text else ""
    except Exception as exc:
        debug_log(f"screenshot: OCR unavailable/failed: {exc}", "screenshot")
        return ""


class ScreenshotTool(Tool):
    """Tool for capturing screenshots and performing OCR."""

    @property
    def name(self) -> str:
        return "screenshot"

    @property
    def description(self) -> str:
        return (
            "Capture the current screen and OCR visible text. "
            "Use only if the screen contents will materially help."
        )

    @property
    def inputSchema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {},
            "required": [],
        }

    def run(
        self,
        args: Optional[Dict[str, Any]],
        context: ToolContext,
    ) -> ToolExecutionResult:
        """Capture the screen and return OCR text."""

        context.user_print("?? Capturing a screenshot for OCR?")
        debug_log("screenshot: capturing OCR...", "screenshot")

        tmpdir = tempfile.mkdtemp(prefix="jarvis_ocr_")
        png_path = os.path.join(tmpdir, "shot.png")
        captured = False

        try:
            # macOS: preserve the repo's interactive selected-region behavior.
            sc = shutil.which("screencapture")
            if sc:
                try:
                    ret = subprocess.run([sc, "-i", png_path])
                    captured = (
                        ret.returncode == 0
                        and os.path.exists(png_path)
                    )
                except Exception as exc:
                    debug_log(
                        f"screenshot: macOS capture failed: {exc}",
                        "screenshot",
                    )

            # Windows: Pillow uses the native Windows screen capture APIs.
            elif os.name == "nt":
                try:
                    from PIL import ImageGrab  # type: ignore

                    image = ImageGrab.grab(all_screens=True)
                    image.save(png_path, "PNG")
                    image.close()
                    captured = os.path.exists(png_path)

                    debug_log(
                        "screenshot: Windows ImageGrab capture succeeded",
                        "screenshot",
                    )
                except Exception as exc:
                    debug_log(
                        f"screenshot: Windows capture failed: {exc}",
                        "screenshot",
                    )
                    return ToolExecutionResult(
                        success=False,
                        reply_text=None,
                        error_message=f"Windows screenshot capture failed: {exc}",
                    )

            else:
                return ToolExecutionResult(
                    success=False,
                    reply_text=None,
                    error_message=(
                        "Screenshot capture is not supported on this platform."
                    ),
                )

            if not captured:
                return ToolExecutionResult(
                    success=False,
                    reply_text=None,
                    error_message="Screenshot capture produced no image.",
                )

            ocr_text = _ocr_image(png_path)

            debug_log(
                f"screenshot: captured=True ocr_chars={len(ocr_text)}",
                "screenshot",
            )
            context.user_print("? Screenshot processed.")

            # Never return an empty successful result. The engine can then
            # distinguish a valid capture with no readable text from a
            # genuine capture failure.
            if ocr_text:
                reply_text = (
                    "Screenshot captured successfully. Visible text:\n"
                    + ocr_text
                )
            else:
                reply_text = (
                    "Screenshot captured successfully. "
                    "No readable text was detected by OCR."
                )

            return ToolExecutionResult(
                success=True,
                reply_text=reply_text,
            )

        finally:
            try:
                if os.path.exists(png_path):
                    os.remove(png_path)
                os.rmdir(tmpdir)
            except Exception:
                pass
