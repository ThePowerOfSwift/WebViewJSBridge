# WebViewJSBridge


	swift与javascript之间进行消息通信
	
参考OC版本: [marcuswestin/WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge) 来实现的，仅供学习用。

## 发现的问题

	javascript脚本是在页面加载完毕，回调：webViewDidFinishLoad方法时注入进去的。假如网页中一个连接超时返回，则需要等待很长一段时间才能完成加载，这个短时间内是做不了通信的。一个可行的方法是手动去获取网页，然后将脚本拼接道网页内容的末尾，这样就可以解决这个问题了，这里不提供解决的代码。
	
相关用法以及API可以参考[marcuswestin/WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)的说明文档


## 截图


![1]()