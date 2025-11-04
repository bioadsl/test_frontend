import os
import tempfile
from PIL import Image


def create_temp_jpg(prefix: str = "upload_img") -> str:
    """Cria uma imagem .jpg temporária (1x1) e retorna o caminho absoluto."""
    tmp_dir = tempfile.gettempdir()
    file_path = os.path.join(tmp_dir, f"{prefix}.jpg")
    img = Image.new("RGB", (1, 1), (255, 255, 255))
    img.save(file_path, format="JPEG")
    return file_path