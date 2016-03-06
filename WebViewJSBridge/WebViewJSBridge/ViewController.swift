//
//  ViewController.swift
//  WebViewJSBridge
//
//  Created by  lifirewolf on 16/3/3.
//  Copyright © 2016年  lifirewolf. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var bridge: WebViewJSBridge!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = UIWebView(frame: self.view.bounds)
        self.view.addSubview(webView)
        
        WebViewJSBridge.enableLogging = true
        
//        bridge = WebViewJSBridge.bridgeForWebView(webView, webViewDelegate: self) { (data, responseCallback) -> Void in
//            //            responseCallback(responseData: data)
//            
//            if let list = data as? [String] {
//                print("imageList: \(list)")
//                //                self.list = list
//            }
//        }
//        
//        bridge.registerHandler("clickImage") { (data, responseCallback) -> Void in
//            print("clickImage: \(data)")
//            
//            //            self.bridge.callHandler("imageList", data: "") { (response) -> Void in
//            //                print("imageList: \(response)")
//            //                if let list = response as? [String] {
//            //                    self.loadPhotoView(list)
//            //                }
//            //            }
//        }
//        
//        loadExamplePage(webView)
        
        WebViewJSBridge.bridgeForWebView(<#T##webView: UIWebView##UIWebView#>, messageHandler: <#T##WVJBHandler##WVJBHandler##(data: AnyObject, responseCallback: WVJBResponseCallback) -> Void#>)
        
        bridge = WebViewJSBridge.bridgeForWebView(webView, webViewDelegate: self, resourceBundle: nil) { data, responseCallback in
            NSLog("ObjC received message from JS: \(data)")
            responseCallback(responseData: "Response for message from ObjC")
        }
        
        bridge.registerHandler("testObjcCallback") { data, responseCallback in
            NSLog("testObjcCallback called: \(data)")
            responseCallback(responseData: "Response from testObjcCallback")
        }
        
        bridge.send("A string sent from ObjC before Webview has loaded.") { responseData in
            NSLog("objc got response! \(responseData)")
        }
        
        bridge.callHandler("testJavascriptHandler", data: ["foo": "before ready"], responseCallback: nil)
        
        renderButtons(webView)
        loadExamplePage(webView)
        
        bridge.send("A string sent from ObjC after Webview has loaded.")
    }
    
    func renderButtons(webView: UIWebView) {
        let font = UIFont(name: "HelveticaNeue", size: 12)
        
        let messageButton = UIButton(type: UIButtonType.RoundedRect)
        messageButton.setTitle("Send message", forState: UIControlState.Normal)
        messageButton.addTarget(self, action:"sendMessage:", forControlEvents: UIControlEvents.TouchUpInside)
        view.insertSubview(messageButton, aboveSubview: webView)
        messageButton.frame = CGRectMake(10, 414, 100, 35)
        messageButton.titleLabel?.font = font
        messageButton.backgroundColor = UIColor(white: 1, alpha: 0.75)
        
        let callbackButton = UIButton(type: UIButtonType.RoundedRect)
        callbackButton.setTitle("Call handler", forState:UIControlState.Normal)
        callbackButton.addTarget(self, action: "callHandler:", forControlEvents: UIControlEvents.TouchUpInside)
        view.insertSubview(callbackButton, aboveSubview: webView)
        callbackButton.frame = CGRectMake(110, 414, 100, 35)
        callbackButton.titleLabel?.font = font
        
        let reloadButton = UIButton(type: UIButtonType.RoundedRect)
        reloadButton.setTitle("Reload webview", forState:UIControlState.Normal)
        reloadButton.addTarget(webView, action: "reload", forControlEvents: UIControlEvents.TouchUpInside)
        view.insertSubview(reloadButton, aboveSubview: webView)
        reloadButton.frame = CGRectMake(210, 414, 100, 35)
        reloadButton.titleLabel?.font = font
    }
    
    func sendMessage(sender: UIButton) {
        bridge.send("A string sent from ObjC to JS") { responseData in
            NSLog("sendMessage got response: \(responseData)")
        }
    }
    
    func callHandler(sender: UIButton) {
        let data = ["greetingFromObjC": "Hi there, JS!"]
        
        bridge.callHandler("testJavascriptHandler", data: data) { responseData in
            NSLog("testJavascriptHandler responded: \(responseData)")
        }
    }
    
    func loadExamplePage(webView: UIWebView) {
        let htmlPath = NSBundle.mainBundle().pathForResource("ExampleApp", ofType: "html")!
//        let htmlPath = NSBundle.mainBundle().pathForResource("Image", ofType: "html")!
        let data = NSData(contentsOfFile: htmlPath)!
        let appHtml = String(data: data, encoding: NSUTF8StringEncoding)!
        let baseURL = NSURL(fileURLWithPath: htmlPath)
        webView.loadHTMLString(appHtml, baseURL: baseURL)
    }
}

extension ViewController: UIWebViewDelegate {
    func webViewDidFinishLoad(webView: UIWebView) {
        NSLog("webViewDidFinishLoad")
    }
    
    func webViewDidStartLoad(webView: UIWebView) {
        NSLog("webViewDidStartLoad")
    }
}
