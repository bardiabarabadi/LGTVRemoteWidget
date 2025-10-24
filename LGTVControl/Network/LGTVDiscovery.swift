import Foundation
import Network

public final class LGTVDiscovery {
    private let browser: NWBrowser
    private var discoveries: [NWBrowser.Result] = []
    
    public init() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // LG TVs advertise as _lge-remote._tcp
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_lge-remote._tcp", domain: nil)
        self.browser = NWBrowser(for: descriptor, using: parameters)
    }
    
    public func discover(timeout: TimeInterval = 5.0) async -> [(name: String, ip: String, port: UInt16)] {
        print("[LGTVDiscovery] 🔍 Starting Bonjour discovery for LG TVs...")
        
        return await withCheckedContinuation { continuation in
            var foundDevices: [(name: String, ip: String, port: UInt16)] = []
            var hasCompleted = false
            
            browser.stateUpdateHandler = { state in
                print("[LGTVDiscovery] Browser state: \(state)")
            }
            
            browser.browseResultsChangedHandler = { results, changes in
                print("[LGTVDiscovery] 📡 Found \(results.count) LG TV(s)")
                
                for result in results {
                    switch result.endpoint {
                    case .service(let name, let type, let domain, let interface):
                        print("[LGTVDiscovery] 📺 Found TV: \(name)")
                        print("[LGTVDiscovery]    Type: \(type), Domain: \(domain), Interface: \(interface?.debugDescription ?? "none")")
                        
                        // Try to resolve the endpoint to get IP
                        if case .hostPort(let host, let port) = result.endpoint {
                            if case .name(let hostname, _) = host {
                                print("[LGTVDiscovery]    Hostname: \(hostname), Port: \(port)")
                            } else if case .ipv4(let ipv4) = host {
                                let ipString = ipv4.debugDescription
                                print("[LGTVDiscovery]    IP: \(ipString), Port: \(port)")
                                foundDevices.append((name: name, ip: ipString, port: port.rawValue))
                            }
                        }
                        
                    case .hostPort(let host, let port):
                        var ipString = ""
                        var nameString = "Unknown"
                        
                        switch host {
                        case .name(let hostname, _):
                            nameString = hostname
                            ipString = hostname
                            print("[LGTVDiscovery] 📺 Found device via hostname: \(hostname):\(port)")
                        case .ipv4(let ipv4):
                            ipString = ipv4.debugDescription
                            print("[LGTVDiscovery] 📺 Found device via IPv4: \(ipString):\(port)")
                        case .ipv6(let ipv6):
                            ipString = ipv6.debugDescription
                            print("[LGTVDiscovery] 📺 Found device via IPv6: \(ipString):\(port)")
                        @unknown default:
                            print("[LGTVDiscovery] ⚠️ Unknown host type")
                        }
                        
                        if !ipString.isEmpty {
                            foundDevices.append((name: nameString, ip: ipString, port: port.rawValue))
                        }
                        
                    default:
                        print("[LGTVDiscovery] ⚠️ Unknown endpoint type: \(result.endpoint)")
                    }
                }
            }
            
            browser.start(queue: .global())
            
            // Wait for timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard !hasCompleted else { return }
                hasCompleted = true
                self.browser.cancel()
                
                print("[LGTVDiscovery] ✅ Discovery complete. Found \(foundDevices.count) device(s)")
                continuation.resume(returning: foundDevices)
            }
        }
    }
}
