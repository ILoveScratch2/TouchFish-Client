"""
TouchFish_Client

客户端模块，用于构建 TouchFish 聊天客户端。
兼容现有 TouchFish LTS

作者: ILoveScratch2
版本: 0.1.1
许可证: MPL-2.0
"""

__version__ = "0.1.1"
__author__ = "ILoveScratch2"
__all__ = ["TouchFishClient", "ClientConfig", "FileTransferHandler"]

import socket
import threading
import platform
import json
import base64
import os
import time
from typing import Callable, Optional, Dict


class ClientConfig:
    """
    客户端配置
    """
    
    def __init__(
        self,
        host: str,
        port: int,
        username: str,
        keepalive_idle: int = 180 * 60,
        keepalive_interval: int = 30
    ):
        self.host = host
        self.port = port
        self.username = username
        self.keepalive_idle = keepalive_idle
        self.keepalive_interval = keepalive_interval


class FileTransferHandler:
    """
    文件传输处理
    """
    
    FILE_START = "[FILE_START]"
    FILE_DATA = "[FILE_DATA]"
    FILE_END = "[FILE_END]"
    CHUNK_SIZE = 8192
    
    def __init__(self, socket_obj: socket.socket):
        self.socket = socket_obj
        self.receiving = False
        self.current_file: Dict = {"name": "", "data": [], "size": 0}
        self.sending_file: Optional[str] = None
        
        self.on_file_start: Optional[Callable[[str, int], bool]] = None
        self.on_file_progress: Optional[Callable[[float], None]] = None
        self.on_file_complete: Optional[Callable[[str, bytes], None]] = None

    def send_file(self, filepath: str) -> bool:
        """
        发送文件 
        读取文件，分块编码并发送。返回是否成功。
        """
        if not os.path.exists(filepath):
            return False
        
        filename = os.path.basename(filepath)
        filesize = os.path.getsize(filepath)
        
        self.sending_file = filename
        
        try:
            start_info = {
                "type": self.FILE_START,
                "name": filename,
                "size": filesize
            }
            self.socket.send(f"{json.dumps(start_info)}\n".encode("utf-8"))
            
            sent_size = 0
            with open(filepath, "rb") as f:
                while True:
                    chunk = f.read(self.CHUNK_SIZE)
                    if not chunk:
                        break
                    
                    chunk_b64 = base64.b64encode(chunk).decode("utf-8")
                    
                    data_info = {
                        "type": self.FILE_DATA,
                        "data": chunk_b64
                    }
                    self.socket.send(f"{json.dumps(data_info)}\n".encode("utf-8"))
                    
                    sent_size += len(chunk)
                    if self.on_file_progress:
                        progress = (sent_size / filesize) * 100
                        self.on_file_progress(progress)
            
            end_info = {"type": self.FILE_END}
            self.socket.send(f"{json.dumps(end_info)}\n".encode("utf-8"))
            
            self.sending_file = None
            return True
            
        except Exception as e:
            self.sending_file = None
            return False

    def handle_file_message(self, message: str) -> bool:
        """
        处理文件传输消息
        根据类型处理文件数据。返回是否为文件消息。
        """
        try:
            msg_data = json.loads(message)
            
            if msg_data["type"] == self.FILE_START:
                if self.sending_file == msg_data["name"]:
                    return True
                
                accept = True
                if self.on_file_start:
                    accept = self.on_file_start(msg_data["name"], msg_data["size"])
                
                if accept:
                    self.receiving = True
                    self.current_file = {
                        "name": msg_data["name"],
                        "data": [],
                        "size": msg_data["size"]
                    }
                return True
            
            elif msg_data["type"] == self.FILE_DATA:
                if self.receiving:
                    chunk_data = base64.b64decode(msg_data["data"])
                    self.current_file["data"].append(chunk_data)
                    
                    if self.on_file_progress:
                        received_size = sum(len(d) for d in self.current_file["data"])
                        progress = (received_size / self.current_file["size"]) * 100
                        self.on_file_progress(progress)
                
                return True
            
            elif msg_data["type"] == self.FILE_END:
                if self.receiving:
                    if self.sending_file == self.current_file["name"]:
                        self.sending_file = None
                        return True
                    
                    file_data = b"".join(self.current_file["data"])
                    filename = self.current_file["name"]
                    
                    if self.on_file_complete:
                        self.on_file_complete(filename, file_data)
                    
                    self.receiving = False
                    self.current_file = {"name": "", "data": [], "size": 0}
                
                return True
            
            return False
            
        except (json.JSONDecodeError, KeyError):
            return False


class TouchFishClient:
    """
    TouchFish 客户端核心
    """
    
    def __init__(self, config: ClientConfig):
        self.config = config
        self.socket: Optional[socket.socket] = None
        self.file_handler: Optional[FileTransferHandler] = None
        self.running = False
        self.receive_thread: Optional[threading.Thread] = None
        self.buffer = b""
        
        self.on_message: Optional[Callable[[str], None]] = None
        self.on_connected: Optional[Callable[[], None]] = None
        self.on_disconnected: Optional[Callable[[], None]] = None
        self.on_error: Optional[Callable[[Exception], None]] = None

    def connect(self) -> bool:
        """
        连接到服务器
        """
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.config.host, self.config.port))
            
            self._configure_socket()
            
            self.file_handler = FileTransferHandler(self.socket)
            
            join_message = f"用户 {self.config.username} 加入聊天室。\n"
            self.socket.send(join_message.encode("utf-8"))
            
            self.running = True
            self.receive_thread = threading.Thread(target=self._receive_loop, daemon=True)
            self.receive_thread.start()
            
            if self.on_connected:
                self.on_connected()
            
            return True
            
        except Exception as e:
            if self.on_error:
                self.on_error(e)
            return False

    def disconnect(self):
        """
        断开连接
        """
        self.running = False
        
        if self.socket:
            try:
                leave_message = f"用户 {self.config.username} 离开了聊天室。"
                self.socket.send(leave_message.encode("utf-8"))
                self.socket.close()
            except:
                pass
        
        if self.on_disconnected:
            self.on_disconnected()

    def send_message(self, message: str):
        """
        发送文本消息
        """
        if not self.socket or not self.running:
            return
        
        while message.startswith("\n"):
            message = message[1:]
        
        if not message.strip():
            return
        
        full_message = f"{self.config.username}: {message}\n"
        
        try:
            self.socket.send(full_message.encode("utf-8"))
        except Exception as e:
            if self.on_error:
                self.on_error(e)

    def send_file(self, filepath: str) -> bool:
        """
        发送文件
        """
        if not self.file_handler:
            return False
        
        return self.file_handler.send_file(filepath)

    def _receive_loop(self):
        """
        接收消息循环
        """
        while self.running:
            time.sleep(0.1)
            
            try:
                chunk = self.socket.recv(1024)
                if not chunk:
                    continue
                
                self.buffer += chunk
                
                while b'\n' in self.buffer:
                    message_bytes, self.buffer = self.buffer.split(b'\n', 1)
                    message = message_bytes.decode('utf-8')
                    
                    if message.startswith("{") and message.endswith("}"):
                        if self.file_handler and self.file_handler.handle_file_message(message):
                            continue
                    
                    if self.on_message:
                        self.on_message(message)
                
            except Exception as e:
                if self.running and self.on_error:
                    self.on_error(e)

    def _configure_socket(self):
        """
        配置连接参数
        """
        if platform.system() == "Windows":
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, True)
            try:
                self.socket.ioctl(
                    socket.SIO_KEEPALIVE_VALS,
                    (1, self.config.keepalive_idle * 1000, self.config.keepalive_interval * 1000)
                )
            except:
                pass
        else:
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, True)
            self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, self.config.keepalive_idle)
            self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, self.config.keepalive_interval)
