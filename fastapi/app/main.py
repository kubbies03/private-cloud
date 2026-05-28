import os
import time
import platform
import logging
import shutil
from datetime import datetime, timedelta
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Gauge, Counter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("enterprise-app")

SECRET_KEY = os.getenv("SECRET_KEY", "lab-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/app/uploads"))
MAX_FILE_SIZE_MB = int(os.getenv("MAX_FILE_SIZE_MB", "10"))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="Enterprise App — Private Cloud Lab",
    description="Mock enterprise application with file storage and monitoring",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

Instrumentator().instrument(app).expose(app)

app.mount("/ui", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")

# ─── Custom Prometheus metrics ────────────────────────────────
files_total = Gauge("app_storage_files_total", "Total number of uploaded files")
storage_bytes = Gauge("app_storage_bytes_total", "Total storage used in bytes")
upload_counter = Counter("app_file_uploads_total", "Total file upload count", ["status"])
download_counter = Counter("app_file_downloads_total", "Total file download count")

def update_storage_metrics():
    files = list(UPLOAD_DIR.glob("*"))
    files_total.set(len(files))
    storage_bytes.set(sum(f.stat().st_size for f in files if f.is_file()))

update_storage_metrics()

# ─── Auth ─────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

USERS_DB = {
    "admin": {
        "username": "admin",
        "full_name": "Administrator",
        "email": "admin@lab.local",
        "hashed_password": pwd_context.hash("admin123"),
        "role": "admin",
        "department": "IT Infrastructure",
    },
    "operator": {
        "username": "operator",
        "full_name": "Cloud Operator",
        "email": "operator@lab.local",
        "hashed_password": pwd_context.hash("operator123"),
        "role": "operator",
        "department": "Operations",
    },
    "viewer": {
        "username": "viewer",
        "full_name": "Read Only User",
        "email": "viewer@lab.local",
        "hashed_password": pwd_context.hash("viewer123"),
        "role": "viewer",
        "department": "Business",
    },
}

START_TIME = time.time()


# ─── Models ──────────────────────────────────────────────────

class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

class UserInfo(BaseModel):
    username: str
    full_name: str
    email: str
    role: str
    department: str

class ServerInfo(BaseModel):
    hostname: str
    platform: str
    uptime_seconds: float
    timestamp: str
    environment: str

class FileInfo(BaseModel):
    filename: str
    size_bytes: int
    uploaded_at: str
    content_type: str


# ─── Auth helpers ─────────────────────────────────────────────

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def authenticate_user(username: str, password: str):
    user = USERS_DB.get(username)
    if not user or not verify_password(password, user["hashed_password"]):
        return None
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = USERS_DB.get(username)
    if user is None:
        raise credentials_exception
    return user


# ─── System routes ───────────────────────────────────────────

@app.get("/health", tags=["System"])
def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/", tags=["System"])
def root():
    return {
        "app": "Enterprise Private Cloud Lab",
        "version": "1.1.0",
        "docs": "/docs",
    }

@app.get("/info", response_model=ServerInfo, tags=["System"])
def server_info():
    return ServerInfo(
        hostname=platform.node(),
        platform=platform.system(),
        uptime_seconds=round(time.time() - START_TIME, 2),
        timestamp=datetime.utcnow().isoformat(),
        environment=os.getenv("APP_ENV", "development"),
    )

@app.get("/services/status", tags=["System"])
def services_status():
    services = [
        {"service": "nginx-proxy",   "status": "running"},
        {"service": "fastapi-app",   "status": "running"},
        {"service": "prometheus",    "status": "running"},
        {"service": "grafana",       "status": "running"},
        {"service": "loki",          "status": "running"},
        {"service": "promtail",      "status": "running"},
        {"service": "node-exporter", "status": "running"},
        {"service": "cadvisor",      "status": "running"},
    ]
    return {"services": services, "total": len(services)}


# ─── Auth routes ─────────────────────────────────────────────

@app.post("/auth/token", response_model=Token, tags=["Auth"])
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        logger.warning("Failed login attempt for user: %s", form_data.username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    expire = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    token = create_access_token({"sub": user["username"], "role": user["role"]}, expire)
    logger.info("User logged in: %s (role=%s)", user["username"], user["role"])
    return Token(
        access_token=token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )

@app.get("/auth/me", response_model=UserInfo, tags=["Auth"])
def get_me(current_user: dict = Depends(get_current_user)):
    return UserInfo(**{k: current_user[k] for k in UserInfo.model_fields})


# ─── Dashboard routes ─────────────────────────────────────────

@app.get("/dashboard", tags=["Dashboard"])
def dashboard(current_user: dict = Depends(get_current_user)):
    logger.info("Dashboard accessed by %s", current_user["username"])
    files = list(UPLOAD_DIR.glob("*"))
    total_size = sum(f.stat().st_size for f in files if f.is_file())
    return {
        "welcome": f"Hello, {current_user['full_name']}",
        "role": current_user["role"],
        "department": current_user["department"],
        "infrastructure": {
            "vms": [
                {"name": "ubuntu-infra",   "ip": "192.168.159.131", "status": "running", "os": "Ubuntu 22.04"},
                {"name": "windows-server", "ip": "192.168.159.132", "status": "running", "os": "Windows Server 2022"},
            ],
            "network": "192.168.159.0/24",
        },
        "storage": {
            "files_uploaded": len(files),
            "total_size_mb": round(total_size / 1024 / 1024, 2),
            "upload_dir": str(UPLOAD_DIR),
        },
        "timestamp": datetime.utcnow().isoformat(),
    }

@app.get("/dashboard/users", tags=["Dashboard"])
def list_users(current_user: dict = Depends(get_current_user)):
    if current_user["role"] not in ("admin", "operator"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    users = [
        {k: v for k, v in u.items() if k != "hashed_password"}
        for u in USERS_DB.values()
    ]
    return {"users": users, "total": len(users)}

@app.get("/dashboard/storage", tags=["Dashboard"])
def storage_info(current_user: dict = Depends(get_current_user)):
    files = list(UPLOAD_DIR.glob("*"))
    total_size = sum(f.stat().st_size for f in files if f.is_file())
    return {
        "upload_dir": str(UPLOAD_DIR),
        "files_count": len(files),
        "total_size_bytes": total_size,
        "total_size_mb": round(total_size / 1024 / 1024, 2),
        "max_file_size_mb": MAX_FILE_SIZE_MB,
        "volumes": [
            {"name": "prometheus-data", "mount": "/prometheus",      "type": "docker-volume"},
            {"name": "grafana-data",    "mount": "/var/lib/grafana", "type": "docker-volume"},
            {"name": "loki-data",       "mount": "/loki",            "type": "docker-volume"},
            {"name": "app-uploads",     "mount": "/app/uploads",     "type": "docker-volume"},
        ],
        "smb_share": "\\\\192.168.159.132\\shared",
        "backup_schedule": "daily at 02:00 UTC",
    }


# ─── File Storage routes ──────────────────────────────────────

@app.post("/files/upload", response_model=FileInfo, tags=["Storage"])
async def upload_file(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    if current_user["role"] not in ("admin", "operator"):
        upload_counter.labels(status="forbidden").inc()
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    # Check file size
    contents = await file.read()
    size = len(contents)
    if size > MAX_FILE_SIZE_MB * 1024 * 1024:
        upload_counter.labels(status="too_large").inc()
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: {MAX_FILE_SIZE_MB}MB"
        )

    dest = UPLOAD_DIR / file.filename
    dest.write_bytes(contents)

    upload_counter.labels(status="success").inc()
    update_storage_metrics()

    logger.info("File uploaded: %s (%d bytes) by %s", file.filename, size, current_user["username"])
    return FileInfo(
        filename=file.filename,
        size_bytes=size,
        uploaded_at=datetime.utcnow().isoformat(),
        content_type=file.content_type or "application/octet-stream",
    )

@app.get("/files", tags=["Storage"])
def list_files(current_user: dict = Depends(get_current_user)):
    files = []
    for f in sorted(UPLOAD_DIR.glob("*")):
        if f.is_file():
            stat = f.stat()
            files.append({
                "filename": f.name,
                "size_bytes": stat.st_size,
                "size_mb": round(stat.st_size / 1024 / 1024, 3),
                "modified_at": datetime.utcfromtimestamp(stat.st_mtime).isoformat(),
            })
    total_size = sum(f["size_bytes"] for f in files)
    return {
        "files": files,
        "count": len(files),
        "total_size_bytes": total_size,
        "total_size_mb": round(total_size / 1024 / 1024, 2),
    }

@app.get("/files/{filename}", tags=["Storage"])
def download_file(
    filename: str,
    current_user: dict = Depends(get_current_user),
):
    path = UPLOAD_DIR / filename
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    download_counter.inc()
    logger.info("File downloaded: %s by %s", filename, current_user["username"])
    return FileResponse(path=str(path), filename=filename)

@app.delete("/files/{filename}", tags=["Storage"])
def delete_file(
    filename: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    path = UPLOAD_DIR / filename
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    path.unlink()
    update_storage_metrics()
    logger.info("File deleted: %s by %s", filename, current_user["username"])
    return {"message": f"File '{filename}' deleted successfully"}
