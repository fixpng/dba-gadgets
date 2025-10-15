from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer
import os
"""
作者：暮渔木鱼  https://blog.krielwus.top/
本脚本用于快速创建一个本地FTP服务器，支持指定文件夹作为FTP根目录，设置用户名和密码，支持多种权限配置。

使用方法：
1. 安装依赖库：pyftpdlib
   pip install pyftpdlib

2. 运行脚本：
   python FTPServerAutoCreate.py

3. 按提示输入你希望作为FTP服务器根目录的文件夹路径。

4. 使用FTP客户端连接服务器，默认端口为21，用户名为"user"，密码为"123456"。

注意事项：
- 请确保端口21未被占用，且有管理员权限（如在Windows下）。
- 如需修改用户名、密码或端口，请在脚本顶部修改相关变量。
- 如需禁用匿名登录，请注释掉 authorizer.add_anonymous(FTP_DIRECTORY) 相关行。
"""

# 配置参数
FTP_PORT = 21
FTP_USER = "user"
FTP_PASSWORD = "123456"
FTP_DIRECTORY = r""  # 修改为你的FTP根目录

def main():
    FTP_DIRECTORY = input("选择文件夹作为ftp服务器> ")
    if not os.path.exists(FTP_DIRECTORY):
        os.makedirs(FTP_DIRECTORY)

    # 实例化虚拟授权器
    authorizer = DummyAuthorizer()

    # 添加用户：用户名、密码、目录、权限
    authorizer.add_user(    
        FTP_USER, 
        FTP_PASSWORD, 
        FTP_DIRECTORY, 
        perm="elradfmw"  # 权限设置：e(改变目录)、l(列表文件)、r(下载)、a(追加文件)、d(删除文件)、f(重命名文件)、m(创建目录)、w(上传文件)
    )

    # 匿名登录配置（如需禁用请注释掉）
    # authorizer.add_anonymous(FTP_DIRECTORY)

    handler = FTPHandler
    handler.authorizer = authorizer
    
    # 自定义欢迎信息
    handler.banner = "PyFTPdlib Server ready."
    
    # 限制连接数
    handler.max_cons = 128
    handler.max_cons_per_ip = 5

    address = ('0.0.0.0', FTP_PORT)
    server = FTPServer(address, handler)

    # 设置最大传输速率 (KB/s)（None表示不限速）
    server.max_upload_speed = None
    server.max_download_speed = None

    try:
        print(f"Starting FTP server on port {FTP_PORT}, directory: {FTP_DIRECTORY}")
        server.serve_forever()
    except KeyboardInterrupt:
        print("FTP server stopped.")
        server.close_all()

if __name__ == '__main__':
    main()