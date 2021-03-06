[ gh, assert, nock ] = require "./test_helper"

describe "github api", ->
  describe "general purpose", ->
    network = null
    success = (done) ->
      (body) ->
        network.done()
        done()
    describe "request", ->
      response = [ { name: "foo", commit: { sha: "abcdef", url: "xxx" } } ]
      beforeEach ->
        network = nock("https://api.github.com")
          .get("/repos/foo/bar/branches")
          .reply(200, response)
      it "accepts a full url", (done) ->
        gh.request("GET", "https://api.github.com/repos/foo/bar/branches").then success done
      it "accepts a path", (done) ->
        gh.request("GET", "repos/foo/bar/branches").then success done
      it "accepts a path (leading slash)", (done) ->
        gh.request("GET", "repos/foo/bar/branches").then success done
      it "includes oauth token if exists", (done) ->
        process.env.HUBOT_GITHUB_TOKEN = "789abc"
        network.matchHeader("Authorization", "token 789abc")
        gh.request("GET", "repos/foo/bar/branches").then success done
        delete process.env.HUBOT_GITHUB_TOKEN
      it "includes accept header", (done) ->
        network.matchHeader('Accept', 'application/vnd.github.v3+json')
        gh.request("GET", "repos/foo/bar/branches").then success done
      it "allows setting API version", (done) ->
        ghPreview = require("../src/githubot") apiVersion: 'preview'
        network.matchHeader('Accept', 'application/vnd.github.preview+json')
        ghPreview.request("GET", "repos/foo/bar/branches").then success done
      it "allows setting API version for single request", (done) ->
        network.matchHeader('Accept', 'application/vnd.github.special+json')
        gh.withOptions(apiVersion: 'special').request("GET", "repos/foo/bar/branches").then success done
      it "allows setting the oauth token for single request", (done) ->
        process.env.HUBOT_GITHUB_TOKEN = "789xyz"
        network.matchHeader("Authorization", "token abc")
        gh.withOptions(token: 'abc').request("GET", "repos/foo/bar/branches").then success done
        delete process.env.HUBOT_GITHUB_TOKEN
      it "doesn't persist per-request options", (done) ->
        network.matchHeader('Accept', 'application/vnd.github.special+json')
        gh.withOptions(apiVersion: 'special').request("GET", "repos/foo/bar/branches").then ->
          network.done()
          network2 = nock("https://api.github.com")
            .get("/repos/baz/bar/branches")
            .matchHeader('Accept', 'application/vnd.github.v3+json')
            .reply(200, response)
          # Should revert to the defaults on this request
          gh.request("GET", "repos/baz/bar/branches").then ->
            network2.done()
            done()
      it "includes User-Agent header", (done) ->
        network.matchHeader('User-Agent', /GitHubot\/\d+\.\d+\.\d+/)
        gh.request("GET", "repos/foo/bar/branches").then success done
      it "returns parsed json", (done) ->
        gh.request("GET", "repos/foo/bar/branches").then (data) ->
          assert.deepEqual response, data
          done()
      context "custom base URL", ->
        beforeEach ->
          network = nock("http://mygithub.internal")
            .get("/repos/foo/bar/branches")
            .reply(200, response)
        it "is used if option exists", (done) ->
          process.env.HUBOT_GITHUB_API = "http://mygithub.internal"
          gh.request("GET", "repos/foo/bar/branches").then success done
          delete process.env.HUBOT_GITHUB_API
        it "is used if passed explicitly", (done) ->
          gh.request("GET", "http://mygithub.internal/repos/foo/bar/branches").then success done

    describe "get", ->
      beforeEach ->
        network = nock("https://api.github.com")
          .get("/gists")
          .reply(200, [])
      it "sends request", (done) ->
        gh.get("gists").then success done

      describe "with params", ->
        beforeEach ->
          network = nock("https://api.github.com")
            .get("/users/foo/repos?foo=bar")
            .reply(200, [])
        it "accepts query params in url", (done) ->
          gh.get("https://api.github.com/users/foo/repos?foo=bar").then success done
        it "accepts query params as hash", (done) ->
          gh.get("users/foo/repos", {foo: "bar"}).then success done

    describe "post", ->
      data = description: "A test gist", public: true, files: { "abc.txt": { content: "abcdefg" } }
      response = url: "http://api.github.com/gists/1", id: 1
      beforeEach ->
        network = nock("https://api.github.com")
          .post("/gists", data)
          .reply(201, response)
      it "sends request", (done) ->
        gh.post("gists", data).then success done

    describe "put", ->
      data = description: "A test gist", public: true, files: { "abc.txt": { content: "abcdefg" } }
      response = url: "http://api.github.com/gists/1", id: 1
      beforeEach ->
        network = nock("https://api.github.com")
          .put("/gists", data)
          .reply(201, response)
      it "sends request", (done) ->
        gh.put("gists", data).then success done

    describe "patch", ->
      data = description: "A test gist", public: true, files: { "abc.txt": { content: "abcdefg" } }
      response = url: "http://api.github.com/gists/1", id: 1
      beforeEach ->
        network = nock("https://api.github.com")
          .patch("/gists", data)
          .reply(201, response)
      it "sends request", (done) ->
        gh.patch("gists", data).then success done

    describe "delete", ->
      it "sends request", (done) ->
        network = nock("https://api.github.com")
          .delete("/gists/345")
          .reply(204)
        gh.delete("gists/345").then success done
      it "includes empty body", (done) ->
        network = nock("https://api.github.com")
          .delete("/gists/345", "")
          .matchHeader("Content-Length", 0)
          .reply(204)
        gh.delete("gists/345").then success done

  describe "errors", ->
    network = null
    http = require "scoped-http-client"
    never_called = ->
      assert.fail(null, null, "Success callback should not be invoked")
    beforeEach ->
      network = nock("https://api.github.com").get("/foo")
    kablooie = ->
      mock = {
        header: -> mock,
        get: () -> (cb) ->
          cb new Error "Kablooie!"
      }
      http._old_create = http.create
      http.create = -> mock
    afterEach ->
      if http._old_create?
        http.create = http._old_create
        http._old_create = null

    it "do not run callback when failed response", (done) ->
      network.reply(401, message: "Bad credentials")
      gh.get("/foo").then never_called, ->
        assert.ok
        done()
    it "do not run callback when  bad response", (done) ->
      network.reply(500, "WTF$$%@! SERVER VOMIT")
      gh.get("/foo").then never_called,  ->
        assert.ok
        done()
    it "do not run callback when  client errors", (done) ->
      kablooie()
      gh.get("/foo").then never_called,  ->
        assert.ok
        done()
