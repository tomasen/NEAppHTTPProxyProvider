//
//  NEAppHTTPProxyProvider.swift
//
//  Created by Tomasen on 2/5/16.
//  Copyright © 2016 PINIDEA LLC. All rights reserved.
//


import NetworkExtension
import CocoaAsyncSocket

struct HTTPProxySet {
    var host: String
    var port: UInt16
}

var proxy = HTTPProxySet(host: "127.0.0.1", port: 3028)

/// A NEAppHTTPProxyProvider sub-class that implements the client side of the http proxy tunneling protocol.
class NEAppHTTPProxyProvider: NEAppProxyProvider {
    
    /// Begin the process of establishing the tunnel.
    override func startProxyWithOptions(options: [String : AnyObject]?, completionHandler: (NSError?) -> Void) {
        
        completionHandler(nil)
    }
    
    /// Begin the process of stopping the tunnel.
    override func stopProxyWithReason(reason: NEProviderStopReason, completionHandler: () -> Void) {
        
        completionHandler()
    }
    
    /// Handle a new flow of network data created by an application.
    override func handleNewFlow(flow: (NEAppProxyFlow?)) -> Bool {
        
        if let TCPFlow = flow as? NEAppProxyTCPFlow {
            let conn = ClientAppHTTPProxyConnection(flow: TCPFlow)
            conn.open()
        }
        
        return false
    }
}

/// An object representing the client side of a logical flow of network data in the SimpleTunnel tunneling protocol.
class ClientAppHTTPProxyConnection : NSObject, GCDAsyncSocketDelegate {
    
    // MARK: Constants
    let bufferSize: UInt = 4096
    let timeout    = 30.0
    let pattern    = "\n\n".dataUsingEncoding(NSUTF8StringEncoding)
    
    // MARK: Properties
    
    /// The NEAppProxyFlow object corresponding to this connection.
    let TCPFlow: NEAppProxyTCPFlow
    
    // MARK: Initializers
    var sock: GCDAsyncSocket!
    
    init(flow: NEAppProxyTCPFlow) {
        TCPFlow = flow
    }
    
    func open() {
        sock = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        do {
            try sock.connectToHost(proxy.host, onPort: proxy.port, withTimeout: 30.0)
        } catch {
            TCPFlow.closeReadWithError(NSError(domain: NEAppProxyErrorDomain, code: NEAppProxyFlowError.NotConnected.rawValue, userInfo: nil))
            return
        }
    }
    
    func socket(sock: GCDAsyncSocket, didConnectToHost host:String, port p:UInt16) {
        
        print("Connected to \(host) on port \(p).")
        
        let remoteHost = (TCPFlow.remoteEndpoint as! NWHostEndpoint).hostname
        let remotePort = (TCPFlow.remoteEndpoint as! NWHostEndpoint).port
        
        // 1. send CONNECT
        // CONNECT www.google.com:80 HTTP/1.1
        sock.writeData(
            "CONNECT \(remoteHost):\(remotePort) HTTP/1.1\n\n"
                .dataUsingEncoding(NSUTF8StringEncoding),
            withTimeout: timeout,
            tag: 1)
        
    }
    
    func didReadFlow(data: NSData?, error: NSError?) {
        // 7. did read from flow
        // 8. write flow data to proxy
        sock.writeData(data, withTimeout: timeout, tag: 0)
        
        // 9. keep reading from flow
        TCPFlow.readDataWithCompletionHandler(self.didReadFlow)
    }
    
    func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        if tag == 1 {
            // 2. CONNECT header sent
            // 3. begin to read from proxy server
            sock.readDataToLength(bufferSize, withTimeout: timeout, tag: 1)
        }
    }
    
    func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        if tag == 1 {
            // 4. read 1st proxy server response of CONNECT
            let range = data.rangeOfData(pattern!,
                options: NSDataSearchOptions(rawValue: 0),
                range: NSMakeRange(0, data.length))
            
            if range.location != NSNotFound {
                let ret = data.rangeOfData("200".dataUsingEncoding(NSUTF8StringEncoding)!,
                    options: NSDataSearchOptions(rawValue: 0),
                    range: NSMakeRange(0, range.location))
                if ret.location != NSNotFound {
                    let loc = range.location+range.length
                    if data.length > loc {
                        // 5. write to flow if there is data already
                        TCPFlow.writeData(data.subdataWithRange(NSMakeRange(loc, data.length - loc)), withCompletionHandler: { error in })
                    }
                    
                    // 6. begin to read from Flow
                    TCPFlow.readDataWithCompletionHandler(self.didReadFlow)
                    
                    // 6.5 keep reading from proxy server
                    sock.readDataToLength(bufferSize, withTimeout: timeout, tag: 0)
                    return
                }
                
            }
            
            // Error: CONNECT failed
            TCPFlow.closeReadWithError(NSError(domain: NEAppProxyErrorDomain, code: NEAppProxyFlowError.NotConnected.rawValue, userInfo: nil))
            sock.disconnect()
            return
        }
        
        // 10. writing any data followed to flow
        TCPFlow.writeData(data, withCompletionHandler: { error in })
        
        // 11. keep reading from proxy server
        sock.readDataToLength(bufferSize, withTimeout: timeout, tag: 0)
    }
    
}