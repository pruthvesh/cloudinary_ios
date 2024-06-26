//
//  CLDNetworkDownloadRequest.swift
//
//  Copyright (c) 2016 Cloudinary (http://cloudinary.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

internal class CLDNetworkDownloadRequest: CLDNetworkDataRequestImpl<CLDNDataRequest>, CLDFetchImageRequest {

    //MARK: - Handlers
    func responseImage(_ completionHandler: CLDCompletionHandler?) -> CLDFetchImageRequest {
        
        return responseData { (responseData, error, statusCode) -> () in
            if let data = responseData {
                if let image = data.cldToUIImageThreadSafe() {
                    completionHandler?(image, nil)
                }
                else {
                    let error = CLDError.error(code: .failedCreatingImageFromData, message: "Failed creating an image from the received data.", userInfo: ["statusCode": statusCode])
                    completionHandler?(nil, error)
                }
            }
            else if let err = error {
                completionHandler?(nil, err)
            }
            else {
                completionHandler?(nil, CLDError.generalError(userInfo: ["statusCode": statusCode]))
            }
        } as! CLDFetchImageRequest
    }
    
    // MARK: - Private
    @discardableResult
    internal func responseData(_ completionHandler: ((_ responseData: Data?, _ error: NSError?, _ httpCode: Int?) -> ())?) -> CLDNetworkDataRequest {
        request.responseData { response in
            let statusCode = response.response?.statusCode
            if let downloadedData = response.result.value {
                if let statusCode = statusCode, self.isAcceptableCode(code: statusCode) {
                    if CLDDownloadCoordinator.enableCache,
                       let result = response.response,
                       let data = response.data,
                       let request = self.request.request,
                       CLDDownloadCoordinator.urlCache.cachedResponse(for: request) == nil {
                        let cachedData = CachedURLResponse(response: result, data: data)
                        CLDDownloadCoordinator.urlCache.storeCachedResponse(cachedData, for: request)
                    }
                    completionHandler?(downloadedData, nil, statusCode)
                }
                else {
                    let statusCodeError = CLDError.error(code: .unacceptableStatusCode, message: "request error - unacceptable statusCode - \(statusCode)", userInfo: ["statusCode": statusCode])
                    completionHandler?(downloadedData, statusCodeError, statusCode)
                }
            }
            else if let err = response.result.error {
                let error = err as NSError
                completionHandler?(nil, error, statusCode)
            }
            else {
                completionHandler?(nil, CLDError.generalError(userInfo: ["statusCode": statusCode]), statusCode)
            }
        }
        return self
    }
    
    func isAcceptableCode(code: Int) -> Bool {
        self.request.acceptableStatusCodes.contains(code)
    }
}
