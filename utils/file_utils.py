import base64
import os
import tempfile

# JPEG mínima (1x1 pixel branco) base64
_MIN_JPG_B64 = (
    b"/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBxISEBUQEhIVFRUVFRUVFRUVFRUVFRUWFhUVFRUYHSggGBolHRUVITEhJSkrLi4uFx8zODMsNygtLisBCgoKDg0OGhAQGi0lHyUtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLf/AABEIAAEAAQMBIgACEQEDEQH/xAAWAAEBAQAAAAAAAAAAAAAAAAAABQj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAgP/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwC2QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/Z"
)


def create_temp_jpg(prefix: str = "upload_img") -> str:
    """Cria uma imagem .jpg temporária e retorna o caminho absoluto."""
    tmp_dir = tempfile.gettempdir()
    file_path = os.path.join(tmp_dir, f"{prefix}.jpg")
    with open(file_path, "wb") as f:
        f.write(base64.b64decode(_MIN_JPG_B64))
    return file_path