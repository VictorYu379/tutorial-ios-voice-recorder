import Foundation


struct VoiceModel: Decodable {
    let id: Int
    let title: String
}

struct VoiceModelsResponse: Decodable {
    let data: [VoiceModel]
}

enum ConversionError: Error {
    case invalidURL
    case badStatus(Int)
    case noData
    case invalidJSON
    case missingOutputURL
}

enum DownloadError: Error {
    case invalidTempURL
    case fileMoveFailed(Error)
    case folderCreationFailed(Error)
}


class VoiceConversionManager {
    let API_KEY = "sJ8_EsQ8.Shd-YuikyGhOMHY8UY8zzbLm"
    
    private var pollTimer: Timer?
    
    func fetchVoiceModels(page: Int, completion: @escaping (Result<[VoiceModel], Error>) -> Void) {
        var components = URLComponents(string: "https://arpeggi.io/api/kits/v1/voice-models")!
        components.queryItems = [
            .init(name: "instruments", value: "true"),
            .init(name: "page", value: String(page)),
            .init(name: "perPage", value: "20")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, resp, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                completion(.failure(NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey: "Bad status \(code)"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(VoiceModelsResponse.self, from: data)
                completion(.success(decoded.data))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
        print("sent HTTP request")
    }
    
    func convert(
        fileURL: URL,
        convertedFileURL: URL,
        trackId: Int,
        modelId: Int,
        octaveShift: Int,
        pollInterval: TimeInterval = 2.0,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let pitchShift = octaveShift * 12
        startVoiceConversion(fileURL: fileURL, convertedFileURL: convertedFileURL, modelId: modelId, pitchShift: pitchShift) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                completion(.failure(err))
                
            case .success(let jobId):
                print("conversion call successful, job id \(jobId)")
                
                // 2) schedule your timer on the main run loop
                DispatchQueue.main.async {
                    // invalidate any existing timer
                    self.pollTimer?.invalidate()
                    
                    self.pollTimer = Timer(timeInterval: pollInterval, repeats: true) { _ in
                        print("fetching conversion...")
                        
                        self.fetchConversion(jobId: jobId) { fetchResult in
                            switch fetchResult {
                            case .failure:
                                // not ready yet—keep polling
                                break
                                
                            case .success(let remoteURL):
                                // stop polling
                                self.pollTimer?.invalidate()
                                self.pollTimer = nil
                                
                                print("will call download")
                                self.downloadWav(from: remoteURL, to: convertedFileURL) { downloadResult in
                                    completion(downloadResult)
                                }
                            }
                        }
                    }
                    
                    // 3) add it to the main run loop in common modes
                    RunLoop.main.add(self.pollTimer!, forMode: .common)
                }
            }
        }
    }
    
    private func startVoiceConversion(
        fileURL: URL,
        convertedFileURL: URL,
        modelId: Int,
        pitchShift: Int,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let url = URL(string: "https://arpeggi.io/api/kits/v1/voice-conversions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        
        // multipart/form-data boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // build HTTP body
        var body = Data()
        let params: [String: String] = [
            "voiceModelId": String(modelId),
            "conversionStrength": "0.5",
            "modelVolumeMix": "0.5",
            "pitchShift": String(pitchShift)
        ]
        // append text fields
        for (key, value) in params {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }
        // append file field
        let filename = fileURL.lastPathComponent
        let mimeType = "audio/wav"         // adjust if different
        let fileData = try! Data(contentsOf: fileURL)
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"soundFile\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        
        // closing boundary
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body
        
        // fire it off
        URLSession.shared.dataTask(with: request) { data, resp, error in
            if let error = error {
                print("Error:", error)
                completion(.failure(error))
                return
            }
            
            // 1) Print the raw URLResponse
            if let http = resp as? HTTPURLResponse {
                print("Status code:", http.statusCode)
                print("Headers:", http.allHeaderFields)
            } else if let resp = resp {
                print("Non-HTTP response:", resp)
            }
            
            guard let data = data else {
                print("No data received")
                completion(.failure(NSError(domain:"", code:0, userInfo:[
                    NSLocalizedDescriptionKey: "No data"
                ])))
                return
            }
            
            // 2) Print the entire body as UTF-8 (or hex/dump if not UTF-8)
            if let bodyString = String(data: data, encoding: .utf8) {
                print("Body:\n\(bodyString)")
            } else {
                print("Body (binary):", data as NSData)
            }
            
            // Now your existing JSON parsing...
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "", code: 0,
                                                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])))
                    return
                }
                // Accept String, Number, or anything that can be stringified
                if let rawId = json["id"], let intId = rawId as? Int {
                    completion(.success(intId))
                } else {
                    completion(.failure(NSError(domain: "", code: 0,
                                                userInfo: [NSLocalizedDescriptionKey: "Missing id in response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func fetchConversion(
        jobId: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let urlString = "https://arpeggi.io/api/kits/v1/voice-conversions/\(jobId)"
        guard let url = URL(string: urlString) else {
            completion(.failure(ConversionError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, resp, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                completion(.failure(ConversionError.invalidURL))
                return
            }
            guard let data = data else {
                completion(.failure(ConversionError.noData))
                return
            }
            guard http.statusCode == 200 else {
                completion(.failure(ConversionError.badStatus(http.statusCode)))
                return
            }
            
            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let urlString = json["outputFileUrl"] as? String,
                    let fileURL = URL(string: urlString)
                else {
                    completion(.failure(ConversionError.missingOutputURL))
                    return
                }
                completion(.success(fileURL))
                
            } catch {
                completion(.failure(ConversionError.invalidJSON))
            }
        }
        .resume()
    }
    
    private func downloadWav(
        from remoteURL: URL,
        to destURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 1) Determine destination folder & file URL
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = docs.appendingPathComponent("ConvertedWavs")
        
        // 2) Ensure the folder exists
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            completion(.failure(DownloadError.folderCreationFailed(error)))
            return
        }
        
        // 3) Download to a temporary location
        let task = URLSession.shared.downloadTask(with: remoteURL) { tempURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let tempURL = tempURL else {
                completion(.failure(DownloadError.invalidTempURL))
                return
            }
            
            // 4) Remove existing file if present
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            
            // 5) Move downloaded file into place
            do {
                try fileManager.moveItem(at: tempURL, to: destURL)
                completion(.success(destURL))
            } catch {
                completion(.failure(DownloadError.fileMoveFailed(error)))
            }
        }
        task.resume()
    }
}

private extension Data {
    /// Appends a UTF-8–encoded string to this Data
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}
