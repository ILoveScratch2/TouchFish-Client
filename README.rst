TouchFish Client 

这是一个非官方的 TouchFish Python库客户端实现。

TouchFish: https://github.com/2044-space-elevator/TouchFish

========================

.. module:: touchfish_client
   :synopsis: TouchFish 客户端模块


该模块兼容现有的 TouchFish LTS 协议。




快速开始
--------

可参考 [example_client.py] 文件中的示例代码。

基本示例
~~~~~~~~

.. code-block:: python

    from touchfish_client import TouchFishClient, ClientConfig

    # 创建客户端配置
    config = ClientConfig(
        host="127.0.0.1",
        port=8080,
        username="Alice"
    )

    # 创建客户端实例
    client = TouchFishClient(config)

    # 设置回调函数
    def on_message(message):
        print(f"收到: {message}")

    client.on_message = on_message

    # 连接服务器
    if client.connect():
        print("连接成功！")
        
        # 发送消息
        client.send_message("你好，世界！")
        
        # 断开连接
        # client.disconnect()


API 参考
--------

ClientConfig
~~~~~~~~~~~~

客户端配置类，用于设置连接参数。

.. class:: ClientConfig(host, port, username, keepalive_idle=10800, keepalive_interval=30)

   :param str host: 服务器地址
   :param int port: 服务器端口
   :param str username: 用户名
   :param int keepalive_idle: TCP keepalive 空闲时间（秒），默认 10800
   :param int keepalive_interval: TCP keepalive 探测间隔（秒），默认 30

   **示例**::

       config = ClientConfig(
           host="chat.example.com",
           port=9000,
           username="Bob"
       )


TouchFishClient
~~~~~~~~~~~~~~~

客户端核心类，处理所有 Socket 操作和消息收发。

.. class:: TouchFishClient(config)

   :param ClientConfig config: 客户端配置对象

   **属性**

   .. attribute:: file_handler

      文件传输处理器实例，连接成功后创建
      
      :type: Optional[FileTransferHandler]

   .. attribute:: running

      客户端运行状态标志
      
      :type: bool

   **回调函数**

   .. attribute:: on_message

      收到消息时的回调函数
      
      :type: Optional[Callable[[str], None]]
      :param str message: 收到的消息内容

   .. attribute:: on_connected

      连接成功时的回调函数
      
      :type: Optional[Callable[[], None]]

   .. attribute:: on_disconnected

      断开连接时的回调函数
      
      :type: Optional[Callable[[], None]]

   .. attribute:: on_error

      发生错误时的回调函数
      
      :type: Optional[Callable[[Exception], None]]
      :param Exception error: 异常对象

   **方法**

   .. method:: connect()

      连接到服务器。
      
      :return: 是否连接成功
      :rtype: bool

      该方法会：
      
      1. 创建 socket 连接
      2. 配置 keepalive 参数
      3. 创建文件传输处理器
      4. 发送加入消息
      5. 启动接收线程
      6. 触发 ``on_connected`` 回调

      **示例**::

          if client.connect():
              print("已连接")
          else:
              print("连接失败")

   .. method:: disconnect()

      断开与服务器的连接。

      该方法会：
      
      1. 发送离开消息
      2. 关闭 socket
      3. 停止接收线程
      4. 触发 ``on_disconnected`` 回调

      **示例**::

          client.disconnect()

   .. method:: send_message(message)

      发送文本消息。

      :param str message: 要发送的消息内容

      消息会自动添加用户名前缀和 ``\n`` 结尾。

      **示例**::

          client.send_message("大家好！")
          # 实际发送: "Alice: 大家好！\n"

   .. method:: send_file(filepath)

      发送文件。

      :param str filepath: 文件路径
      :return: 是否发送成功
      :rtype: bool

      **示例**::

          if client.send_file("/path/to/file.txt"):
              print("文件发送成功")


FileTransferHandler
~~~~~~~~~~~~~~~~~~~

文件传输处理器类，处理文件的发送和接收。

.. class:: FileTransferHandler(socket_obj)

   :param socket.socket socket_obj: Socket 对象

   **常量**

   .. attribute:: FILE_START
      :annotation: = "[FILE_START]"

   .. attribute:: FILE_DATA
      :annotation: = "[FILE_DATA]"

   .. attribute:: FILE_END
      :annotation: = "[FILE_END]"

   .. attribute:: CHUNK_SIZE
      :annotation: = 8192

   **回调函数**

   .. attribute:: on_file_start

      收到文件传输开始时的回调
      
      :type: Optional[Callable[[str, int], bool]]
      :param str filename: 文件名
      :param int filesize: 文件大小（字节）
      :return: 是否接受文件
      :rtype: bool

   .. attribute:: on_file_progress

      文件传输进度更新时的回调
      
      :type: Optional[Callable[[float], None]]
      :param float progress: 进度百分比（0-100）

   .. attribute:: on_file_complete

      文件传输完成时的回调
      
      :type: Optional[Callable[[str, bytes], None]]
      :param str filename: 文件名
      :param bytes file_data: 文件数据

   **方法**

   .. method:: send_file(filepath)

      发送文件。

      :param str filepath: 文件路径
      :return: 是否发送成功
      :rtype: bool

      该方法会：
      
      1. 发送 FILE_START 消息（包含文件名和大小）
      2. 分块读取文件并 base64 编码
      3. 发送 FILE_DATA 消息（每块 8192 字节）
      4. 调用 ``on_file_progress`` 回调
      5. 发送 FILE_END 消息

   .. method:: handle_file_message(message)

      处理文件传输消息（内部使用）。

      :param str message: JSON 格式的消息
      :return: 是否为文件消息
      :rtype: bool


完整示例
--------

交互式客户端
~~~~~~~~~~~~

.. code-block:: python

    from touchfish_client import TouchFishClient, ClientConfig
    import os

    # 配置
    config = ClientConfig(
        host=input("服务器地址: "),
        port=int(input("端口: ")),
        username=input("用户名: ")
    )

    client = TouchFishClient(config)

    # 消息回调
    def on_message(message):
        if not message.startswith(f"{config.username}:"):
            print(f"\n{message}")
            print("> ", end="", flush=True)

    # 连接回调
    def on_connected():
        print("已连接到服务器")

    # 错误回调
    def on_error(error):
        print(f"错误: {error}")

    # 文件接收回调
    def on_file_start(filename, filesize):
        print(f"\n收到文件: {filename} ({filesize/1024/1024:.2f} MB)")
        return input("是否接收? (y/n): ").lower() == 'y'

    def on_file_progress(progress):
        print(f"\r进度: {progress:.1f}%", end="", flush=True)

    def on_file_complete(filename, file_data):
        save_path = input(f"\n保存路径 [{filename}]: ") or filename
        with open(save_path, "wb") as f:
            f.write(file_data)
        print(f"已保存: {save_path}")

    # 设置回调
    client.on_message = on_message
    client.on_connected = on_connected
    client.on_error = on_error

    # 连接
    if not client.connect():
        print("连接失败")
        exit(1)

    # 设置文件回调（必须在 connect 之后）
    if client.file_handler:
        client.file_handler.on_file_start = on_file_start
        client.file_handler.on_file_progress = on_file_progress
        client.file_handler.on_file_complete = on_file_complete

    # 消息循环
    try:
        while client.running:
            msg = input("> ").strip()
            
            if msg == "/quit":
                client.disconnect()
                break
            
            elif msg.startswith("/file "):
                filepath = msg[6:].strip()
                if os.path.exists(filepath):
                    if client.send_file(filepath):
                        print("文件发送完成")
                else:
                    print("文件不存在")
            
            else:
                client.send_message(msg)
    
    except KeyboardInterrupt:
        client.disconnect()


只接收消息
~~~~~~~~~~

.. code-block:: python

    from touchfish_client import TouchFishClient, ClientConfig
    import time

    config = ClientConfig(host="127.0.0.1", port=8080, username="Observer")
    client = TouchFishClient(config)

    client.on_message = lambda msg: print(msg)

    if client.connect():
        print("开始监听...")
        try:
            while client.running:
                time.sleep(1)
        except KeyboardInterrupt:
            client.disconnect()


协议说明
--------

发送格式
~~~~~~~~

**文本消息**::

    用户名: 消息内容\n

**加入消息**::

    用户 用户名 加入聊天室。\n

**离开消息**::

    用户 用户名 离开了聊天室。

**文件传输**::

    {"type": "[FILE_START]", "name": "文件名", "size": 字节数}\n
    {"type": "[FILE_DATA]", "data": "base64编码的数据块"}\n
    {"type": "[FILE_END]"}\n

