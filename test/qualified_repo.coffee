[ gh, assert, nock ] = require "./test_helper"

describe "qualified_repo", ->
  it "returns full name when given full name", ->
    assert.equal "foo/bar", gh.qualified_repo "foo/bar"
  it "converts to lower case", ->
    assert.equal "foo/bar", gh.qualified_repo "FoO/BAR"
  it "retrieves github username from env", ->
    process.env.HUBOT_GITHUB_USER = "watson"
    assert.equal "watson/bar", gh.qualified_repo "bar"
    delete process.env.HUBOT_GITHUB_USER
  it "retrieves github user&repo from env", ->
    process.env.HUBOT_GITHUB_USER = "watson"
    process.env.HUBOT_GITHUB_REPO = "baz"
    assert.equal "watson/baz", gh.qualified_repo null
    delete process.env.HUBOT_GITHUB_REPO
    delete process.env.HUBOT_GITHUB_USER
  it "retrieves fully qualified github repo from env", ->
    process.env.HUBOT_GITHUB_USER = "watson"
    process.env.HUBOT_GITHUB_REPO = "sherlock/bar"
    assert.equal "sherlock/bar", gh.qualified_repo null
    assert.equal "sherlock/bar", gh.qualified_repo()
    delete process.env.HUBOT_GITHUB_USER
    delete process.env.HUBOT_GITHUB_REPO
