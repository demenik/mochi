//
//  HostModuleInterop+Http.swift
//
//
//  Created by ErrorErrorError on 5/9/23.
//
//

import Foundation
import WasmInterpreter

// MARK: HTTP Imports

// swiftlint:disable closure_parameter_position cyclomatic_complexity
extension ModuleClient.Instance {
    func httpImports() -> WasmInstance.Import {
        WasmInstance.Import(namespace: "http") {
            WasmInstance.Function("create") { [self] (method: Int32) -> Int32 in
                hostAllocations.withValue { alloc in
                    alloc.add(WasmRequest(method: .init(rawValue: method) ?? .GET))
                }
            }

            WasmInstance.Function("send") { [self] (ptr: ReqRef) in
                hostAllocations.withValue { alloc in
                    guard var request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    guard let urlRequest = request.generateURLRequest() else {
                        return
                    }

                    let semaphore = DispatchSemaphore(value: 0)
                    var response: WasmRequest.Response?
                    defer { alloc[ptr] = request }

                    let dataTask = URLSession.shared.dataTask(with: urlRequest) { data, resp, error in
                        defer { semaphore.signal() }

                        guard let httpResponse = resp as? HTTPURLResponse else {
                            return
                        }

                        if let error {
                            response = .init(
                                statusCode: httpResponse.statusCode,
                                data: nil,
                                error: error
                            )
                        }

                        if let data {
                            response = .init(
                                statusCode: httpResponse.statusCode,
                                data: data,
                                error: nil
                            )
                        }
                    }
                    dataTask.resume()
                    semaphore.wait()

                    request.response = response
                }
            }

            WasmInstance.Function("close") { [self] (ptr: ReqRef) in
                hostAllocations.withValue { $0[ptr] = nil }
            }

            WasmInstance.Function("set_url") { [self] (
                ptr: ReqRef,
                urlPtr: Int32,
                urlLen: Int32
            ) in
                hostAllocations.withValue { alloc in
                    guard var request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    request.url = try? memory.string(
                        byteOffset: Int(urlPtr),
                        length: Int(urlLen)
                    )

                    alloc[ptr] = request
                }
            }

            WasmInstance.Function("set_header") { [self] (
                ptr: ReqRef,
                keyPtr: Int32,
                keyLen: Int32,
                valuePtr: Int32,
                valueLen: Int32
            ) in
                hostAllocations.withValue { alloc in
                    guard var request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    guard let header = try? memory.string(
                        byteOffset: Int(keyPtr),
                        length: Int(keyLen)
                    ) else {
                        return
                    }

                    guard let value = try? memory.string(
                        byteOffset: Int(valuePtr),
                        length: Int(valueLen)
                    ) else {
                        return
                    }

                    request.headers[header] = value

                    alloc[ptr] = request
                }
            }

            WasmInstance.Function("set_body") { [self] (
                ptr: Int32,
                dataPtr: Int32,
                dataLen: Int32
            ) in
                hostAllocations.withValue { alloc in
                    guard var request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    request.body = try? memory.data(
                        byteOffset: Int(dataPtr),
                        length: Int(dataLen)
                    )

                    alloc[ptr] = request
                }
            }

            WasmInstance.Function("set_method") { [self] (
                ptr: Int32,
                method: Int32
            ) in
                hostAllocations.withValue { alloc in
                    guard var request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    request.method = .init(rawValue: method) ?? .GET

                    alloc[ptr] = request
                }
            }

            WasmInstance.Function("get_method") { [self] (
                ptr: Int32
            ) -> WasmRequest.Method.RawValue in
                hostAllocations.withValue { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        return WasmRequest.Method.GET.rawValue
                    }
                    return request.method.rawValue
                }
            }

            WasmInstance.Function("get_url") { [self] (
                ptr: Int32
            ) -> Int32 in
                handleErrorAlloc { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        throw ModuleClient.Error.castError()
                    }

                    guard let url = request.url else {
                        throw ModuleClient.Error.nullPtr()
                    }

                    return alloc.add(url)
                }
            }

            WasmInstance.Function("get_header") { [self] (
                ptr: Int32,
                keyPtr: Int32,
                keyLen: Int32
            ) -> Int32 in
                handleErrorAlloc { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        throw ModuleClient.Error.castError()
                    }

                    let key = try memory.string(
                        byteOffset: Int(keyPtr),
                        length: Int(keyLen)
                    )

                    guard let value = request.headers[key] else {
                        throw ModuleClient.Error.nullPtr()
                    }

                    return alloc.add(value)
                }
            }

            WasmInstance.Function("get_status_code") { [self] (
                ptr: Int32
            ) -> Int32 in
                handleErrorAlloc { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        throw ModuleClient.Error.castError()
                    }

                    guard let statusCode = request.response?.statusCode else {
                        throw ModuleClient.Error.nullPtr()
                    }

                    return .init(statusCode)
                }
            }

            WasmInstance.Function("get_data_len") { [self] (
                ptr: ReqRef
            ) -> Int32 in
                hostAllocations.withValue { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        return 0
                    }

                    guard let data = request.response?.data else {
                        return 0
                    }

                    return Int32(data.count)
                }
            }

            WasmInstance.Function("get_data") { [self] (
                ptr: Int32,
                arrRef: Int32,
                arrLen: Int32
            ) in
                hostAllocations.withValue { alloc in
                    guard let request = alloc[ptr] as? WasmRequest else {
                        return
                    }

                    guard let data = request.response?.data else {
                        return
                    }

                    try? memory.write(
                        with: data.dropLast(data.count - Int(arrLen)),
                        byteOffset: Int(arrRef)
                    )
                }
            }
        }
    }
}

// MARK: - WasmRequest

struct WasmRequest: KVAccess {
    var url: String?
    var method: Method = .GET
    var body: Data?
    var headers: [String: String] = [:]
    var response: Response?

    enum Method: Int32, CustomStringConvertible {
        case GET
        case POST
        case PUT
        case PATCH
        case DELETE

        var description: String {
            switch self {
            case .GET:
                return "GET"
            case .POST:
                return "POST"
            case .PUT:
                return "PUT"
            case .PATCH:
                return "PATCH"
            case .DELETE:
                return "DELETE"
            }
        }
    }

    struct Response: KVAccess {
        let statusCode: Int
        let data: Data?
        let error: Error?
    }

    func generateURLRequest() -> URLRequest? {
        guard let url, let url = URL(string: url) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.description
        body.flatMap { request.httpBody = $0 }
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return request
    }
}
