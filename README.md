# 停车场车牌快速链接页面

该项目会在本地启动一个极简网页，内置鲁BFF6505、鲁B2290L 两个车牌的快捷操作：
点击“复制车牌号”即可快速复制号码，同时提供通往学校官方查询地址
[http://skdtcsf.sdust.edu.cn/pms/carParkMobile/carpayment/search](http://skdtcsf.sdust.edu.cn/pms/carParkMobile/carpayment/search)
的跳转按钮。我们不会主动为您搜索或抓取任何停车信息，只是帮您快速打开官方页面。

## 运行方式

项目仅依赖 Python 标准库，无需额外安装第三方包。可直接执行以下命令启动：

```bash
python -m parking_monitor.webapp
```

默认监听在 `http://127.0.0.1:8000`。打开浏览器访问该地址，即可看到包含两个车牌卡片的界面：

1. 点击“复制车牌号”按钮，将车牌复制到剪贴板；
2. 点击“打开查询页面”在新的浏览器标签中打开学校的停车缴费查询网址；
3. 在官方页面中将刚复制的车牌粘贴到输入框，即可进行查询。

> 如果复制失败（例如浏览器限制剪贴板访问），页面底部会给出提示。
> 这时可以直接选中文本后按 <kbd>Ctrl</kbd> + <kbd>C</kbd> 手动复制。

## 自定义端口或地址

如需修改监听端口或地址，可在启动命令中传入参数：

```bash
python -m parking_monitor.webapp --host 0.0.0.0 --port 9000
```

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
