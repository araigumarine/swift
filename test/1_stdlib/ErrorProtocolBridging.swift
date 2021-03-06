// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

import StdlibUnittest


import Foundation
import CoreLocation
import Darwin

var ErrorProtocolBridgingTests = TestSuite("ErrorProtocolBridging")

var NoisyErrorLifeCount = 0
var NoisyErrorDeathCount = 0
var CanaryHandle = 0

protocol OtherProtocol {
  var otherProperty: String { get }
}

protocol OtherClassProtocol : class {
  var otherClassProperty: String { get }
}

class NoisyError : ErrorProtocol, OtherProtocol, OtherClassProtocol {
  init() { NoisyErrorLifeCount += 1 }
  deinit { NoisyErrorDeathCount += 1 }

  let _domain = "NoisyError"
  let _code = 123

  let otherProperty = "otherProperty"
  let otherClassProperty = "otherClassProperty"
}

@objc enum EnumError : Int, ErrorProtocol {
  case BadError = 9000
  case ReallyBadError = 9001
}

ErrorProtocolBridgingTests.test("NSError") {
  NoisyErrorLifeCount = 0
  NoisyErrorDeathCount = 0
  autoreleasepool {
    let ns = NSError(domain: "SomeDomain", code: 321, userInfo: nil)

    objc_setAssociatedObject(ns, &CanaryHandle, NoisyError(),
                             .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let e: ErrorProtocol = ns
    expectEqual(e._domain, "SomeDomain")
    expectEqual(e._code, 321)

    let ns2 = e as NSError
    expectTrue(ns === ns2)
    expectEqual(ns2._domain, "SomeDomain")
    expectEqual(ns2._code, 321)
  }
  expectEqual(NoisyErrorDeathCount, NoisyErrorLifeCount)
}

ErrorProtocolBridgingTests.test("NSError-to-enum bridging") {
  NoisyErrorLifeCount = 0
  NoisyErrorDeathCount = 0
  autoreleasepool {
    let ns = NSError(domain: NSCocoaErrorDomain,
                     code: NSFileNoSuchFileError,
                     userInfo: nil)

    objc_setAssociatedObject(ns, &CanaryHandle, NoisyError(),
                             .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  
    let e: ErrorProtocol = ns

    let cocoaCode: Int?
    switch e {
    case let x as NSCocoaError:
      cocoaCode = x._code
      expectTrue(x.isFileError)
      expectEqual(x, NSCocoaError.fileNoSuchFileError)
      expectEqual(x.hashValue, NSFileNoSuchFileError)
    default:
      cocoaCode = nil
    }

    expectEqual(cocoaCode, NSFileNoSuchFileError)

    let cocoaCode2: Int? = (ns as? NSCocoaError)?._code
    expectEqual(cocoaCode2, NSFileNoSuchFileError)

    let isNoSuchFileError: Bool
    switch e {
    case NSCocoaError.fileNoSuchFileError:
      isNoSuchFileError = true
    default:
      isNoSuchFileError = false
    }

    expectTrue(isNoSuchFileError)

    // NSURLError domain
    let nsURL = NSError(domain: NSURLErrorDomain,
                        code: NSURLErrorBadURL,
                        userInfo: nil)
    let eURL: ErrorProtocol = nsURL
    let isBadURLError: Bool
    switch eURL {
    case NSURLError.badURL:
      isBadURLError = true
    default:
      isBadURLError = false
    }

    expectTrue(isBadURLError)

    // CoreLocation error domain
    let nsCL = NSError(domain: kCLErrorDomain,
                       code: CLError.headingFailure.rawValue,
                       userInfo: [:])
    let eCL: ErrorProtocol = nsCL
    let isHeadingFailure: Bool
    switch eCL {
    case CLError.headingFailure:
      isHeadingFailure = true
    default:
      isHeadingFailure = false
    }

    expectTrue(isHeadingFailure)

    // NSPOSIXError domain
    let nsPOSIX = NSError(domain: NSPOSIXErrorDomain,
                          code: Int(EDEADLK),
                          userInfo: [:])
    let ePOSIX: ErrorProtocol = nsPOSIX
    let isDeadlock: Bool
    switch ePOSIX {
    case POSIXError.EDEADLK:
      isDeadlock = true
    default:
      isDeadlock = false
    }

    expectTrue(isDeadlock)

    // NSMachError domain
    let nsMach = NSError(domain: NSMachErrorDomain,
                         code: Int(KERN_MEMORY_FAILURE),
                         userInfo: [:])
    let eMach: ErrorProtocol = nsMach
    let isMemoryFailure: Bool
    switch eMach {
    case MachError.KERN_MEMORY_FAILURE:
      isMemoryFailure = true
    default:
      isMemoryFailure = false
    }

    expectTrue(isMemoryFailure)
  }
  
  expectEqual(NoisyErrorDeathCount, NoisyErrorLifeCount)
}

func opaqueUpcastToAny<T>(_ x: T) -> Any {
  return x
}

struct StructError: ErrorProtocol {
  var _domain: String { return "StructError" }
  var _code: Int { return 4812 }
}

ErrorProtocolBridgingTests.test("ErrorProtocol-to-NSError bridging") {
  NoisyErrorLifeCount = 0
  NoisyErrorDeathCount = 0
  autoreleasepool {
    let e: ErrorProtocol = NoisyError()
    let ns = e as NSError
    let ns2 = e as NSError
    expectTrue(ns === ns2)
    expectEqual(ns._domain, "NoisyError")
    expectEqual(ns._code, 123)

    let e3: ErrorProtocol = ns
    expectEqual(e3._domain, "NoisyError")
    expectEqual(e3._code, 123)
    let ns3 = e3 as NSError
    expectTrue(ns === ns3)

    let nativeNS = NSError(domain: NSCocoaErrorDomain,
                           code: NSFileNoSuchFileError,
                           userInfo: nil)

    objc_setAssociatedObject(ns, &CanaryHandle, NoisyError(),
                             .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let nativeE: ErrorProtocol = nativeNS
    let nativeNS2 = nativeE as NSError
    expectTrue(nativeNS === nativeNS2)
    expectEqual(nativeNS2._domain, NSCocoaErrorDomain)
    expectEqual(nativeNS2._code, NSFileNoSuchFileError)

    let any: Any = NoisyError()
    let ns4 = any as! NSError
    expectEqual(ns4._domain, "NoisyError")
    expectEqual(ns4._code, 123)

    let ao: AnyObject = NoisyError()
    let ns5 = ao as! NSError
    expectEqual(ns5._domain, "NoisyError")
    expectEqual(ns5._code, 123)

    let any2: Any = StructError()
    let ns6 = any2 as! NSError
    expectEqual(ns6._domain, "StructError")
    expectEqual(ns6._code, 4812)
  }
  expectEqual(NoisyErrorDeathCount, NoisyErrorLifeCount)
}

ErrorProtocolBridgingTests.test("enum-to-NSError round trip") {
  autoreleasepool {
    // Emulate throwing an error from Objective-C.
    func throwNSError(_ error: EnumError) throws {
      throw NSError(domain: "main.EnumError", code: error.rawValue,
                    userInfo: [:])
    }

    var caughtError: Bool

    caughtError = false
    do {
      try throwNSError(.BadError)
      expectUnreachable()
    } catch let error as EnumError {
      expectEqual(.BadError, error)
      caughtError = true
    } catch _ {
      expectUnreachable()
    }
    expectTrue(caughtError)

    caughtError = false
    do {
      try throwNSError(.ReallyBadError)
      expectUnreachable()
    } catch EnumError.BadError {
      expectUnreachable()
    } catch EnumError.ReallyBadError {
      caughtError = true
    } catch _ {
      expectUnreachable()
    }
    expectTrue(caughtError)
  }
}

class SomeNSErrorSubclass: NSError {}


ErrorProtocolBridgingTests.test("Thrown NSError identity is preserved") {
  do {
    let e = NSError(domain: "ClericalError", code: 219,
                    userInfo: ["yeah": "yeah"])
    do {
      throw e
    } catch let e2 as NSError {
      expectTrue(e === e2)
      expectTrue(e2.userInfo["yeah"] as? String == "yeah")
    } catch {
      expectUnreachable()
    }
  }

  do {
    let f = SomeNSErrorSubclass(domain: "ClericalError", code: 219,
                                userInfo: ["yeah": "yeah"])
    do {
      throw f
    } catch let f2 as NSError {
      expectTrue(f === f2)
      expectTrue(f2.userInfo["yeah"] as? String == "yeah")
    } catch {
      expectUnreachable()
    }
  }
}

runAllTests()
