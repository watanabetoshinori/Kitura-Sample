/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

// KituraSample shows examples for creating custom routes.

import Foundation

import Kitura
import KituraNet
import KituraSession
//import KituraMustache

import LoggerAPI
import HeliumLogger

import Credentials
import CredentialsHTTP

import SwiftyJSON

#if os(Linux)
    import Glibc
#endif


// All Web apps need a router to define routes
let router = Router()

// Using an implementation for a Logger
HeliumLogger.use()

// Using a session
let session = Session(secret: "Some secret")

// Basic Authentication
let users = ["John" : "12345", "Mary" : "qwerasdf"]

let basicCredentials = CredentialsHTTPBasic(userProfileLoader: { userId, callback in
    if let storedPassword = users[userId] {
        callback(userProfile: UserProfile(id: userId, displayName: userId, provider: "HTTPBasic"), password: storedPassword)
    } else {
        callback(userProfile: nil, password: nil)
    }
})

let credentials = Credentials()
credentials.register(plugin: basicCredentials)

/**
 * ContentTypeMiddleware set default Content-Type.
 */
class ContentTypeMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        response.type("html", charset: "utf-8")
        next()
    }
}

// Variable to post/put data to (just for sample purposes)
var name: String?

// Session enabled
router.all(middleware: session)

// Basic Authentication enabled
router.all("/secure", middleware: credentials)

// This route executes the default content type middleware
router.all(middleware: ContentTypeMiddleware())

// Serve static content from "public"
router.all("/static", middleware: StaticFileServer())

// This route accepts GET requests
router.get("/hello") { _, response, next in
     let fName = name ?? "World"
     try response.end("Hello \(fName), from Kitura!")
}

// This route accepts POST requests
router.post("/hello") {request, response, next in
    name = try request.readString()
    try response.end("Got a POST request")
}

// This route accepts PUT requests
router.put("/hello") {request, response, next in
    name = try request.readString()
    try response.end("Got a PUT request")
}

// This route accepts DELETE requests
router.delete("/hello") {_, response, next in
    name = nil
    try response.end("Got a DELETE request")
}

// Session example
router.get("/session/add/:name") { request, response, next in
    let name = request.parameters["name"] ?? ""
    request.session?["user"] = JSON(["name": name])
    request.session?.save(callback: { (error) in
        if let error = error {
            Log.error("\(error)")
        }
    })
    
    try response.end("\(name) is stored in the session.")
}

router.get("/session/show") { request, response, next in
    let json = request.session?["user"]
    
    let name = json?["name"].string ?? "(nill)"

    try response.end("Hello \(name), from Kitura")
}

// Basic Authentication example
router.get("/secure") { _, response, next in
    let fName = name ?? "World"
    try response.end("Hello \(fName), this is secure page!")
}

// Error handling example
router.get("/error") { _, response, next in
    Log.error("Example of error being set")
    response.status(.internalServerError)
    response.error = NSError(domain: "RouterTestDomain", code: 1, userInfo: [:])
    next()
}

// Redirection example
router.get("/redir") { _, response, next in
    try response.redirect("http://www.ibm.com")
    next()
}

// Content-Type example
router.get("/txt") { _, response, next in
    response.type("txt")
    let fName = name ?? "World"
    try response.end("Hello \(fName), from Kitura!")
}

// JSON example
router.get("/json") { _, response, next in
    let json = JSON(["name":"Jack", "age": 25])
    try response.send(json: json).end()
}

// HTTP client example
router.get("/feed") { _, response, next in
    var options: [ClientRequest.Options] = []
    options.append(.method("GET"))
    options.append(.schema("https://"))
    options.append(.hostname("developer.ibm.com"))
    options.append(.path("/swift/feed/"))
    
    let request = HTTP.request(options) { httpResponse in
        do {
            var body = NSMutableData()
            try httpResponse?.readAllData(into: body)
            let str = String(data: body, encoding: NSUTF8StringEncoding)!
            
            response.type("rss")
            
            try response.end(str)
        } catch let error {
            try! response.end("Caught the error: \(error)")
        }
    }
    
    request.end()
}

// Reading parameters
// Accepts user as a parameter
router.get("/users/:user") { request, response, next in
    let p1 = request.parameters["user"] ?? "(nil)"
    try response.end(
        "<!DOCTYPE html><html><body>" +
        "<b>User:</b> \(p1)" +
        "</body></html>\n\n")
}

// Uses multiple handler blocks
router.get("/multi", handler: { _, response, next in
    response.send("I'm here!\n")
    next()
}, { _, response, next in
    response.send("Me too!\n")
    next()
})

router.get("/multi") { _, response, next in
    try response.end("I come afterward..\n")
}

// Support for Mustache implemented for OSX only yet
//#if !os(Linux)
//router.setDefaultTemplateEngine(templateEngine: MustacheTemplateEngine())
//
//router.get("/trimmer") { _, response, next in
//    defer {
//        next()
//    }
//    // the example from https://github.com/groue/GRMustache.swift/blob/master/README.md
//    var context: [String: Any] = [
//        "name": "Arthur",
//        "date": NSDate(),
//        "realDate": NSDate().addingTimeInterval(60*60*24*3),
//        "late": true
//    ]
//
//    // Let template format dates with `{{format(...)}}`
//    let dateFormatter = NSDateFormatter()
//    dateFormatter.dateStyle = .mediumStyle
//    context["format"] = dateFormatter
//
//    try response.render("document", context: context).end()
//}
//#endif

// Handles any errors that get set
router.error { _, response, next in
    let errorDescription: String
    if let error = response.error {
        errorDescription = "\(error)"
    } else {
        errorDescription = "Unknown error"
    }
    try response.end("Caught the error: \(errorDescription)")
}

// A custom Not found handler
router.all { request, response, next in
    if response.statusCode == .unknown {
        // Remove this wrapping if statement, if you want to handle requests to / as well
        if request.originalURL != "/" && request.originalURL != ""  {
            try response.status(.notFound).end("Route not found in Sample application!")
        }
    }
    next()
}

// Add HTTP Server to listen on port 8090
Kitura.addHTTPServer(onPort: 8090, with: router)

// start the framework - the servers added until now will start listening
Kitura.run()
