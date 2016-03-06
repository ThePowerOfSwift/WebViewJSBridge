//
//  WebViewJSBridgeBase.swift
//  WebViewJSBridge
//
//  Created by  lifirewolf on 16/3/3.
//  Copyright © 2016年  lifirewolf. All rights reserved.
//

import UIKit

let kCustomProtocolScheme = "wvjbscheme"
let kQueueHasMessage = "__WVJB_QUEUE_MESSAGE__"

typealias WVJBResponseCallback = (responseData: AnyObject?) -> Void
typealias WVJBHandler = (data: AnyObject, responseCallback: WVJBResponseCallback) -> Void
typealias WVJBMessage = NSDictionary

protocol WebViewJSBridgeBaseDelegate: NSObjectProtocol {
    func evaluateJavascript(javascriptCommand: String) -> String?
}

class WebViewJSBridgeBase: NSObject {
    var delegate: WebViewJSBridgeBaseDelegate?
    var startupMessageQueue: [WVJBMessage]?
    var responseCallbacks = [String: WVJBResponseCallback]()
    var messageHandlers = [String: WVJBHandler]()
    var messageHandler: WVJBHandler?
    var numRequestsLoading = 0
    
    private var webViewDelegate: UIWebViewDelegate!
    private var uniqueId = 0
    private var resourceBundle: NSBundle?
    
    static var enableLogging = false
    
    init(messageHandler: WVJBHandler?, resourceBundle bundle: NSBundle?) {
        self.messageHandler = messageHandler
        resourceBundle = bundle
        startupMessageQueue = [WVJBMessage]()
    }
    
    func reset() {
        startupMessageQueue = [WVJBMessage]()
        responseCallbacks = [String: WVJBResponseCallback]()
        uniqueId = 0
    }
    
    func sendData(data: AnyObject?, handlerName: String?, responseCallback: WVJBResponseCallback?) {
        var message = [String: AnyObject]()
        if let data = data {
            message["data"] = data
        }
        
        if let callBack = responseCallback {
            let callbackId = "objc_cb_\(++uniqueId)"
            self.responseCallbacks[callbackId] = callBack
            message["callbackId"] = callbackId
        }
        
        if let name = handlerName {
            message["handlerName"] = name
        }
        
        queueMessage(message)
    }
    
    func flushMessageQueue(messageQueueString: String) {
        guard let messages = deserializeMessageJSON(messageQueueString) else {
            NSLog("WebViewJavascriptBridge: WARNING: Invalid received: %@", messageQueueString)
            return
        }
        
        for message in messages {
            log("RCVD", json: message)
            
            if let responseId = message["responseId"] as? String {
                if let responseCallback = responseCallbacks[responseId] {
                    responseCallback(responseData: message["responseData"])
                    responseCallbacks.removeValueForKey(responseId)
                }
            } else {
                var responseCallback: WVJBResponseCallback
                if let callbackId = message["callbackId"] {
                    responseCallback = { responseData in
                        if let data = responseData {
                            
                            let msg = ["responseId": callbackId, "responseData": data]
                            
                            self.queueMessage(msg)
                        }
                    }
                } else {
                    responseCallback = { ignoreResponseData in
                        // Do nothing
                    }
                }
                
                let handler: WVJBHandler?
                if let handlerName = message["handlerName"] as? String {
                    handler = self.messageHandlers[handlerName]
                } else {
                    handler = self.messageHandler
                }
                
                if handler == nil {
                    NSLog("WVJBNoHandlerException, No handler for message from JS: %@", message)
                    return
                }
                
                handler!(data: message["data"]!, responseCallback: responseCallback)
            }
        }
    }
    
    func injectJavascriptFile(shouldInject: Bool) {
        if shouldInject {
            let bundle = resourceBundle ?? NSBundle.mainBundle()
            let filePath = bundle.pathForResource("WebViewJavascriptBridge.js", ofType: "txt")!
            
            let data = NSData(contentsOfFile: filePath)!
            let js = String(data: data, encoding: NSUTF8StringEncoding)!
            
            evaluateJavascript(js)
            
            dispatchStartUpMessageQueue()
        }
    }
    
    func dispatchStartUpMessageQueue() {
        if let queue = startupMessageQueue {
            for queuedMessage in queue {
                dispatchMessage(queuedMessage)
            }
            self.startupMessageQueue = nil
        }
    }
    
    func isCorrectProcotocolScheme(url: NSURL?) -> Bool {
        if url?.scheme == kCustomProtocolScheme {
            return true
        }
        return false
    }
    
    func isCorrectHost(url: NSURL?) -> Bool {
        if url?.host == kQueueHasMessage {
            return true
        }
        return false
    }
    
    func logUnkownMessage(url: NSURL?) {
        NSLog("WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command \(kCustomProtocolScheme)://\(url?.path)")
    }
    
    func webViewJavascriptCheckCommand() -> String {
        return "typeof WebViewJavascriptBridge == \'object\';"
    }
    
    func webViewJavascriptFetchQueyCommand() -> String {
        return "WebViewJavascriptBridge._fetchQueue();"
    }
    
    private func dispatchMessage(message: WVJBMessage) {
        var messageJSON = serializeMessage(message)
        log("SEND", json: messageJSON)
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\\", withString: "\\\\")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\'", withString: "\\\'")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\n", withString: "\\\n")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\r", withString: "\\\r")
//        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\\f", withString: "\\\\f")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\\u2028", withString: "\\\\u2028")
        messageJSON = messageJSON.stringByReplacingOccurrencesOfString("\\u2029", withString: "\\\\u2029")
        
        let javascriptCommand = "WebViewJavascriptBridge._handleMessageFromObjC('\(messageJSON)');"
        if NSThread.currentThread().isMainThread {
            evaluateJavascript(javascriptCommand)
        } else {
            dispatch_sync(dispatch_get_main_queue()) {
                self.evaluateJavascript(javascriptCommand)
            }
        }
    }

    private func evaluateJavascript(js: String) {
        delegate?.evaluateJavascript(js)
    }
    
    private func queueMessage(message: WVJBMessage) {
        if nil != startupMessageQueue {
            startupMessageQueue!.append(message)
        } else {
            dispatchMessage(message)
        }
    }

    private func serializeMessage(message: AnyObject) -> String {
        let data = try! NSJSONSerialization.dataWithJSONObject(message, options: NSJSONWritingOptions())
        return String(data: data, encoding: NSUTF8StringEncoding)!
    }

    private func deserializeMessageJSON(messageQueueString: String) -> [WVJBMessage]? {
        
        if let data = messageQueueString.dataUsingEncoding(NSUTF8StringEncoding) {
            return try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! [WVJBMessage]
        }
        return nil
    }
    
    private func log(action: String, var json: AnyObject) {
        if !WebViewJSBridgeBase.enableLogging {
            return
        }
        if !(json is String) {
            json = serializeMessage(json)
        }
        
        NSLog("WVJB \(action): \(json)")
    }
}
