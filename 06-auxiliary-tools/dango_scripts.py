
from django.conf import settings
from mirage.crypto import Crypto

# 确保 Django 设置已经加载
if not settings.configured:
    settings.configure(
        SECRET_KEY= "hfusaf2m4ot#7)fkw#di4aa6(cv0@opwmafx5n#8=3d%x^hpl6",
        # 添加其他必要的设置
    )

# 现在你可以安全地使用 Crypto 类
c = Crypto()                      # key is optional, default will use settings.SECRET_KEY
print(c.encrypt('app_user'))  # 输出加密后的字符串
print(c.decrypt('8pN9XbNnXHp7iust4Ts_9Q=='))  # 输出解密后的字符串
