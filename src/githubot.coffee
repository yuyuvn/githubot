http = require "scoped-http-client"
querystring = require "querystring"

version = require("../package.json")["version"]

class Github
  constructor: (@options) ->

  withOptions: (specialOptions) ->
    newOpts = {}
    newOpts[k] = v for k,v of @options
    newOpts[k] = v for k,v of specialOptions
    new @constructor newOpts

  qualified_repo: (repo) ->
    unless repo?
      unless (repo = @_opt "defaultRepo")?
        return null
    repo = repo.toLowerCase()
    return repo unless repo.indexOf("/") is -1
    unless (user = @_opt "defaultUser")?
      return repo
    "#{user}/#{repo}"
  request: (verb, url, data) ->
    url_api_base = @_opt("apiRoot")

    if url[0..3] isnt "http"
      url = "/#{url}" unless url[0] is "/"
      url = "#{url_api_base}#{url}"
    req = http.create(url).header("Accept", "application/vnd.github.#{@_opt "apiVersion"}+json")
    req = req.header("User-Agent", "GitHubot/#{version}")
    oauth_token = @_opt "token"
    req = req.header("Authorization", "token #{oauth_token}") if oauth_token?
    args = []
    args.push JSON.stringify data if data?
    args.push "" if verb is "DELETE" and not data?
    new Promise (resolve, reject) ->
      req[verb.toLowerCase()](args...) (err, res, body) =>
        if err?
          reject
            statusCode: res?.statusCode
            body: res?.body
            error: err
        try
          responseData = JSON.parse body if body
        catch e
          reject
            statusCode: res.statusCode
            body: body
            error: "Could not parse response: #{body}"

        if (200 <= res.statusCode < 300)
          resolve responseData
        else
          reject
            statusCode: res.statusCode
            body: body
            error: responseData.message

  get: (url, data) ->
    if data?
      url += "?" + querystring.stringify data
    @request "GET", url

  post: (url, data, cb) ->
    @request "POST", url, data

  delete: (url, cb) ->
    @request "DELETE", url

  put: (url, data, cb) ->
    @request "PUT", url, data

  patch: (url, data, cb) ->
    @request "PATCH", url, data

  handleErrors: (callback) ->
    @options.errorHandler = callback

  _opt: (optName) ->
    @options ?= {}
    @options[optName] ? @_optFromEnv(optName)
  _optFromEnv: (optName) ->
    switch optName
      when "token"
        process.env.HUBOT_GITHUB_TOKEN
      when "concurrentRequests"
        process.env.HUBOT_CONCURRENT_REQUESTS ? 20
      when "defaultRepo"
        process.env.HUBOT_GITHUB_REPO
      when "defaultUser"
        process.env.HUBOT_GITHUB_USER
      when "apiRoot"
        process.env.HUBOT_GITHUB_API ? "https://api.github.com"
      when "apiVersion"
        process.env.HUBOT_GITHUB_API_VERSION ? "v3"
      else null

module.exports = github = (options = {}) ->
  new Github options

github[method] = func for method,func of Github.prototype
