//
//  WebViewJSBridge.swift
//  WebViewJSBridge
//
//  Created by  lifirewolf on 16/3/3.
//  Copyright © 2016年  lifirewolf. All rights reserved.
//

import UIKit

class WebViewJSBridge: NSObject {
    
    private var webView: UIWebView!
    private var webViewDelegate: UIWebViewDelegate!
    private var uniqueId = 0
    private var base: WebViewJSBridgeBase!
    private var numRequestsLoading = 0
    
    static var enableLogging: Bool {
        get {
            return WebViewJSBridgeBase.enableLogging
        }
        set {
            WebViewJSBridgeBase.enableLogging = newValue
        }
    }
    
    static func bridgeForWebView(webView: UIWebView, webViewDelegate: UIWebViewDelegate? = nil, resourceBundle bundle: NSBundle? = nil, messageHandler handler: WVJBHandler) -> WebViewJSBridge {
        let bridge = WebViewJSBridge()
        bridge.platformSpecificSetup(webView, webViewDelegate: webViewDelegate, resourceBundle: bundle, messageHandler: handler)
        return bridge
    }
    
    func send(data: AnyObject?, responseCallback: WVJBResponseCallback? = nil) {
        base.sendData(data, handlerName: nil, responseCallback: responseCallback)
    }
    
    func callHandler(handlerName: String, data: AnyObject? = nil, responseCallback: WVJBResponseCallback? = nil) {
        base.sendData(data, handlerName: handlerName, responseCallback: responseCallback)
    }
    
    func registerHandler(handlerName: String, handler: WVJBHandler) {
        base.messageHandlers[handlerName] = handler
    }

    private func platformSpecificSetup(webView: UIWebView, webViewDelegate: UIWebViewDelegate? = nil, resourceBundle bundle: NSBundle? = nil, messageHandler handler: WVJBHandler) {
        self.webView = webView
        webView.delegate = self
        self.webViewDelegate = webViewDelegate
        base = WebViewJSBridgeBase(messageHandler: handler, resourceBundle: bundle)
        base.delegate = self
    }
}

extension WebViewJSBridge: WebViewJSBridgeBaseDelegate {
    func evaluateJavascript(javascriptCommand: String) -> String? {
        return webView.stringByEvaluatingJavaScriptFromString(javascriptCommand)
    }
}

extension WebViewJSBridge: UIWebViewDelegate {
    
    func webViewDidFinishLoad(webView: UIWebView) {
        if webView != self.webView {
            return
        }
        
        numRequestsLoading--
        
        if numRequestsLoading == 0 && webView.stringByEvaluatingJavaScriptFromString(base.webViewJavascriptCheckCommand()) != "true" {
            base.injectJavascriptFile(true)
        }
        
        base.dispatchStartUpMessageQueue()
        
        if let delegate = webViewDelegate {
            if delegate.respondsToSelector("webViewDidFinishLoad:") {
                delegate.webViewDidFinishLoad!(webView)
            }
        }
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        if webView != self.webView {
            return
        }
        numRequestsLoading--
        
        if let delegate = webViewDelegate {
            if delegate.respondsToSelector("webView:didFailLoadWithError:") {
                delegate.webView!(webView, didFailLoadWithError: error)
            }
        }
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if webView != self.webView {
            return true
        }
        
        let url = request.URL
        
        if base.isCorrectProcotocolScheme(url) {
            
            if base.isCorrectHost(url) {
                if let messageQueueString = evaluateJavascript(base.webViewJavascriptFetchQueyCommand()) {
                    base.flushMessageQueue(messageQueueString)
                }
                
            } else {
                base.logUnkownMessage(url)
            }
            
            return false
            
        } else if let delegate = webViewDelegate {
            if delegate.respondsToSelector("webView:shouldStartLoadWithRequest:navigationType:") {
                return delegate.webView!(webView, shouldStartLoadWithRequest: request, navigationType: navigationType)
            }
        }
        
        return true
    }
    
    func webViewDidStartLoad(webView: UIWebView) {
        if webView != self.webView {
            return
        }
        numRequestsLoading++
        
        if let delegate = webViewDelegate {
            if delegate.respondsToSelector("webViewDidStartLoad:") {
                delegate.webViewDidStartLoad!(webView)
            }
        }
    }
}
