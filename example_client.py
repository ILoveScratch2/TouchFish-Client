"""
TouchFish_Client 使用示例

By ILoveScratch2
License: BSD-3-Clause
"""

from touchfish_client import TouchFishClient, ClientConfig
import sys
import time
import os


def main(): # 主函数
    print("=== TouchFish_Client 示例 ===")
    print("By ILoveScratch2")
    
    host = input("服务器地址 [127.0.0.1]: ").strip() or "127.0.0.1"
    port = input("端口 [8080]: ").strip() or "8080"
    username = input("用户名: ").strip()
    
    if not username:
        print("用户名不能为空")
        return
    
    try:
        port = int(port)
    except:
        print("端口必须是数字")
        return
    
    config = ClientConfig(
        host=host,
        port=port,
        username=username
    )
    
    client = TouchFishClient(config)
    
    def on_message(message):
        """
        收到消息
        """
        if not message.startswith(f"{username}:"):
            print(f"\n{message}")
            print("> ", end="", flush=True)
    
    def on_connected():
        """
        连接成功
        """
        print(f"已连接到 {host}:{port}")
        print("命令: /file <路径>(发送文件) | /quit(退出)")
        print("-" * 50)
    
    def on_disconnected():
        """
        断开连接
        """
        print("\n已断开连接")
    
    def on_error(error):
        """
        错误
        """
        print(f"\n错误: {error}")
    
    def on_file_start(filename, filesize):
        """
        收到文件开始
        """
        size_mb = filesize / 1024 / 1024
        print(f"\n收到文件: {filename} ({size_mb:.2f} MB)",end=" ")
        response = input("是否接收? (y/n): ").strip().lower()
        return response == 'y'
    
    def on_file_progress(progress):
        """
        文件传输进度
        """
        print(f"\r传输进度: {progress:.1f}%", end="", flush=True)
    
    def on_file_complete(filename, file_data):
        """
        文件接收完成
        """
        save_path = input(f"\n保存路径 [./{filename}]: ").strip() or f"./{filename}"
        
        os.makedirs(os.path.dirname(save_path) or ".", exist_ok=True)
        
        with open(save_path, "wb") as f:
            f.write(file_data)
        
        print(f"文件已保存: {save_path}")
        print("> ", end="", flush=True)
    
    client.on_message = on_message
    client.on_connected = on_connected
    client.on_disconnected = on_disconnected
    client.on_error = on_error
    
    if not client.connect():
        print("连接失败")
        return
    
    if client.file_handler:
        client.file_handler.on_file_start = on_file_start 
        client.file_handler.on_file_progress = on_file_progress
        client.file_handler.on_file_complete = on_file_complete
    
    try:
        while client.running:
            msg = input("> ").strip()
            
            if not msg:
                continue
            
            if msg == "/quit":
                client.disconnect()
                break
            
            elif msg.startswith("/file "):
                filepath = msg[6:].strip().strip('"')
                
                if not os.path.exists(filepath):
                    print("文件不存在")
                    continue
                
                print(f"正在发送文件: {filepath}")
                if client.send_file(filepath): # 发送文件函数
                    print("文件发送完成")
                else:
                    print("文件发送失败")
            
            else:
                client.send_message(msg) # 发送消息函数
    
    except KeyboardInterrupt:
        print("\n正在退出...")
        client.disconnect() # 断开连接函数


if __name__ == "__main__":
    main()
